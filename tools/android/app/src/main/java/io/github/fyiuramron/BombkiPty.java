package io.github.fyiuramron;

import android.content.Context;
import android.os.Build;
import android.util.Base64;
import android.util.Log;
import android.webkit.WebView;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

/**
 * Runs the bundled BOMBKI game library inside a pseudo terminal and
 * bridges it to the xterm.js terminal in {@link MainActivity}.
 *
 * <p>The game is a Turbo Pascal 7 text-mode program: it writes ANSI escape
 * sequences and reads single keystrokes, so it needs a real tty rather than
 * pipes. The pty itself lives in {@code native/pty.c}, which also forks the
 * child and starts the game: the child needs the pty slave as its fds 0/1/2
 * and the game as a dlopen'd library, and neither can be arranged after the
 * fact from Java.
 *
 * <p>Bytes are handed to the terminal page base64-encoded, since
 * {@code evaluateJavascript} only accepts UTF-8 strings and the game's CP437
 * output is not valid UTF-8.
 *
 * <p>The game prints its splash screen as its first output, which races the
 * WebView's page load: until the page has loaded, evaluateJavascript runs
 * against about:blank and the writes go nowhere. So output is buffered here
 * and replayed once the page calls back through {@link #ready()}.
 */
final class BombkiPty {

    private static final String TAG = "BombkiPty";
    private static final int COLUMNS = 80;
    private static final int ROWS = 25;

    /** ABI the game library is packaged under. */
    private static final String ABI = "arm64-v8a";

    /** Name of the game library inside the app's native library directory. */
    private static final String GAME_LIBRARY = "libbombki.so";

    /** Directory the game keeps its save file (pliki.tpu) in. */
    private static final String WORK_DIR = "save";

    private final Context context;
    private final WebView terminal;

    /** Guards pageReady and pending: the reader thread produces output while
     * the WebView thread consumes it via ready(). */
    private final Object outputLock = new Object();
    private boolean pageReady;
    private final ByteArrayOutputStream pending = new ByteArrayOutputStream();

    private volatile int masterFd = -1;
    private volatile int pid = -1;
    private Thread reader;
    private volatile boolean running;

    BombkiPty(Context context, WebView terminal) {
        this.context = context.getApplicationContext();
        this.terminal = terminal;
    }

    void attach() {
        if (running) {
            return;
        }
        try {
            start();
        } catch (Throwable error) {
            Log.e(TAG, "could not start BOMBKI", error);
            reportFatal("could not start BOMBKI", error.toString());
        }
    }

    void detach() {
        // The game keeps its save files relative to the working directory, so the
        // session is left running while the activity is merely backgrounded.
    }

    void close() {
        stop();
    }

    /**
     * The terminal page calls this once xterm.js is open. Everything the game
     * printed before now is held in the buffer and replayed in order.
     */
    void ready() {
        synchronized (outputLock) {
            pageReady = true;
            if (pending.size() > 0) {
                byte[] flush = pending.toByteArray();
                pending.reset();
                // Posted while still holding the lock, so output the game
                // produces from here on cannot be queued ahead of the
                // replay.
                evaluate("__bombkiWrite", base64(flush));
            }
        }
    }

    /** Sends keystrokes from the terminal page to the game's stdin. */
    void sendInput(String base64) {
        byte[] data;
        try {
            data = Base64.decode(base64, Base64.DEFAULT);
        } catch (IllegalArgumentException error) {
            Log.w(TAG, "ignoring undecodable input", error);
            return;
        }
        int fd = masterFd;
        if (fd < 0 || data.length == 0) {
            return;
        }
        int written = Native.write(fd, data);
        if (written < 0) {
            Log.w(TAG, "input write failed");
        }
    }

    private void start() throws IOException {
        File library = gameLibrary();
        // The game keeps its save file (pliki.tpu) relative to the
        // working directory, so give it a private directory of its own.
        File workingDirectory = new File(context.getFilesDir(), WORK_DIR);
        if (!workingDirectory.isDirectory() && !workingDirectory.mkdirs()) {
            throw new IOException("cannot create the working directory: " + workingDirectory);
        }
        if (!library.isFile()) {
            throw new IOException("the game library is missing: " + library
                    + " (the APK did not ship lib/" + ABI + "/" + GAME_LIBRARY + ")");
        }
        int[] master = new int[1];
        Log.i(TAG, "loading " + library + " in " + workingDirectory);
        pid = Native.start(library.getAbsolutePath(), workingDirectory.getAbsolutePath(),
                COLUMNS, ROWS, master);
        if (pid < 0 || master[0] < 0) {
            throw new IOException("could not start " + library);
        }
        masterFd = master[0];
        running = true;
        reader = new Thread(this::pump, "bombki-pty-reader");
        reader.setDaemon(true);
        reader.start();
        Log.i(TAG, "game started, pid " + pid + ", pty fd " + masterFd);
    }

    private void pump() {
        byte[] buffer = new byte[8192];
        while (running) {
            int count = Native.read(masterFd, buffer);
            if (count == 0) {
                // Poll timeout with nothing pending; check whether to keep going.
                continue;
            }
            if (count < 0) {
                break;
            }
            byte[] chunk = new byte[count];
            System.arraycopy(buffer, 0, chunk, 0, count);
            deliver(chunk);
        }
        running = false;
        int status = waitForExit();
        Log.i(TAG, "game exited with status " + status);
        if (status >= 128) {
            reportFatal("BOMBKI crashed", "the game was killed by "
                    + signalName(status - 128) + " (exit status " + status + ")");
        } else {
            deliver(("\r\n[BOMBKI zakonczyl dzialanie, kod wyjscia " + status + "]\r\n")
                    .getBytes(StandardCharsets.UTF_8));
        }
    }

    /**
     * Prints a critical error on the game's terminal. A failure has to be
     * readable from the screen itself: whoever reports it is usually holding
     * the device, and digging the same facts out of logcat is far more
     * tedious than reading a dump the error already sits on. So every
     * detail that could explain the failure goes out as ordinary terminal
     * output, ahead of anything else the session would print.
     */
    private void reportFatal(String title, String cause) {
        StringBuilder report = new StringBuilder(2048);
        report.append("\r\n");
        report.append("*** BOMBKI: ").append(title).append(" ***\r\n");
        report.append(cause).append("\r\n");
        report.append("\r\n");
        report.append("--- diagnostic dump ---\r\n");
        detail(report, "game library", describeLibrary());
        detail(report, "working directory",
                new File(context.getFilesDir(), WORK_DIR).getAbsolutePath());
        detail(report, "package", context.getPackageName());
        detail(report, "apk", context.getPackageCodePath());
        detail(report, "android", Build.VERSION.RELEASE
                + " (SDK " + Build.VERSION.SDK_INT + ")");
        detail(report, "security patch", String.valueOf(Build.VERSION.SECURITY_PATCH));
        detail(report, "device", Build.MANUFACTURER + " " + Build.MODEL
                + " (brand " + Build.BRAND + ")");
        detail(report, "fingerprint", Build.FINGERPRINT);
        detail(report, "abis", join(Build.SUPPORTED_ABIS));
        detail(report, "selinux context", readFile("/proc/self/attr/current"));
        detail(report, "data mounts", dataMounts());
        detail(report, "exec probe", execProbe());
        deliver(report.toString().getBytes(StandardCharsets.UTF_8));
    }

    private static void detail(StringBuilder report, String name, String value) {
        report.append(name).append(": ");
        if (value.indexOf('\n') >= 0) {
            // Multi-line values (the mount table, and so on) get their
            // own indented block so the key itself stays readable.
            report.append("\r\n").append(value);
        } else {
            report.append(value).append("\r\n");
        }
    }

    private File gameLibrary() {
        return new File(context.getApplicationInfo().nativeLibraryDir, GAME_LIBRARY);
    }

    private String describeLibrary() {
        File library = gameLibrary();
        StringBuilder text = new StringBuilder(library.getAbsolutePath());
        if (library.isFile()) {
            text.append(" (").append(library.length()).append(" bytes, readable: ")
                    .append(library.canRead()).append(')');
        } else {
            text.append(" (MISSING: the APK did not ship the game library)");
        }
        return text.toString();
    }

    /** Reads a /proc file of this process; they are small plain text. */
    private static String readFile(String path) {
        try (InputStream in = new FileInputStream(path)) {
            byte[] buffer = new byte[1024];
            int count = in.read(buffer);
            return count > 0
                    ? new String(buffer, 0, count, StandardCharsets.UTF_8).trim()
                    : "(empty)";
        } catch (IOException error) {
            return "unreadable: " + error;
        }
    }

    /**
     * The mounts that hold the app's data and libraries, with their
     * options: a noexec policy there would show up in this line.
     */
    private String dataMounts() {
        StringBuilder text = new StringBuilder();
        try (BufferedReader mounts = new BufferedReader(new InputStreamReader(
                new FileInputStream("/proc/mounts"), StandardCharsets.UTF_8))) {
            String line;
            while ((line = mounts.readLine()) != null) {
                String[] fields = line.split("\\s+");
                if (fields.length < 4 || !holdsAppData(fields[1])) {
                    continue;
                }
                text.append(fields[0]).append(" on ").append(fields[1])
                        .append(": type ").append(fields[2])
                        .append(", options ").append(fields[3]).append("\r\n");
            }
        } catch (IOException error) {
            text.append("unreadable: ").append(error).append("\r\n");
        }
        return text.length() > 0 ? text.toString() : "(none found)";
    }

    private boolean holdsAppData(String mountPoint) {
        String files = context.getFilesDir().getAbsolutePath();
        String libraries = context.getApplicationInfo().nativeLibraryDir;
        return mountPoint.equals("/") || mountPoint.equals("/data")
                || files.startsWith(mountPoint) || libraries.startsWith(mountPoint);
    }

    /**
     * Tells the two exec failure classes apart: a device that refuses
     * execve outright fails here too, while a device that only marks the
     * app's data mount noexec still runs this probe from /system.
     */
    private String execProbe() {
        try {
            Process probe = new ProcessBuilder("/system/bin/sh", "-c", "exit 0").start();
            probe.waitFor();
            return "/system/bin/sh ran (exit " + probe.exitValue()
                    + "): execve works from this app";
        } catch (Throwable error) {
            return "FAILED: " + error;
        }
    }

    private static String signalName(int signal) {
        switch (signal) {
            case 1: return "SIGHUP";
            case 2: return "SIGINT";
            case 3: return "SIGQUIT";
            case 4: return "SIGILL";
            case 6: return "SIGABRT";
            case 7: return "SIGBUS";
            case 8: return "SIGFPE";
            case 9: return "SIGKILL";
            case 11: return "SIGSEGV";
            case 13: return "SIGPIPE";
            case 15: return "SIGTERM";
            default: return "signal " + signal;
        }
    }

    private static String join(String[] parts) {
        StringBuilder text = new StringBuilder();
        for (String part : parts) {
            if (text.length() > 0) {
                text.append(", ");
            }
            text.append(part);
        }
        return text.toString();
    }

    /** Reaps the game briefly, since a failed read can outlive the game. */
    private int waitForExit() {
        for (int attempt = 0; attempt < 50; attempt++) {
            int status = Native.awaitExit(pid);
            if (status >= 0) {
                return status;
            }
            try {
                Thread.sleep(100);
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return -1;
            }
        }
        return -1;
    }

    /** Routes game output to the terminal page, holding it back until the page
     * has reported that xterm.js is ready. */
    private void deliver(byte[] data) {
        synchronized (outputLock) {
            if (!pageReady) {
                pending.write(data, 0, data.length);
                return;
            }
        }
        evaluate("__bombkiWrite", base64(data));
    }

    private void evaluate(String function, String encoded) {
        terminal.post(() -> terminal.evaluateJavascript(
                "window." + function + " && window." + function + "('" + encoded + "')", null));
    }

    private static String base64(byte[] data) {
        return Base64.encodeToString(data, Base64.NO_WRAP);
    }

    private void stop() {
        running = false;
        int fd = masterFd;
        if (fd >= 0) {
            Native.close(fd);
            masterFd = -1;
        }
        if (reader != null) {
            reader.interrupt();
            reader = null;
        }
    }

    /** Holds the JNI shims; see {@code tools/android/native/pty.c}. */
    static final class Native {

        static {
            try {
                System.loadLibrary("bombkipty");
            } catch (UnsatisfiedLinkError error) {
                throw new RuntimeException("the pty helper library is missing", error);
            }
        }

        private Native() {
        }

        /**
         * Starts the game library on a new pty. Returns the child's pid,
         * filling outMasterFd[0] with the master side, or -1 on failure.
         */
        static native int start(String library, String workingDirectory, int columns, int rows,
                                int[] outMasterFd);

        static native int read(int fd, byte[] buffer);

        static native int write(int fd, byte[] buffer);

        /** Returns the exit status, or -1 while the game is still running. */
        static native int awaitExit(int pid);

        static native void close(int fd);
    }
}
