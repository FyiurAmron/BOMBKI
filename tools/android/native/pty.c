/*
 * pty.c - spawn BOMBKI on a pseudo terminal.
 *
 * BOMBKI is a Turbo Pascal 7 text-mode program: it writes ANSI escape
 * sequences and reads single keystrokes, so it needs a real tty rather
 * than pipes. Android's bionic libc has no forkpty(), so the pty is
 * opened the way bionic's own sources do it internally: open /dev/ptmx,
 * unlock it with TIOCSPTLCK, then read the slave number with TIOCGPTN.
 *
 * The fork and the game launch live here rather than in Java because the
 * child must inherit the pty slave as its fds 0/1/2. Doing that with
 * Java's ProcessBuilder plus dup2 would rewire the app's own descriptors
 * instead of the child's, since ProcessBuilder has already forked by the
 * time Java sees the descriptors.
 *
 * The game is not executed: the APK ships it as the shared library
 * libbombki.so, and the child loads it with dlopen and calls its
 * exported BombkiMain. execve of a file under the app's data directory
 * is refused by some devices' security policy no matter what permissions
 * the app sets, while dlopen of the app's own libraries is the path
 * Android itself uses for JNI, so no policy blocks it.
 *
 * A pipe reports why the child failed. Every failure path in the child
 * writes the failing step, errno and a human-readable reason to it
 * before _exit(127); a successful start closes the pipe's write end
 * instead, so the parent sees EOF exactly when the game is running.
 * Without it a failed launch is indistinguishable from a game that
 * simply printed nothing.
 */

#define _GNU_SOURCE /* pipe2 with O_CLOEXEC */

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <jni.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

/* Entry point the game library exports for this child: the BombkiMain
 * procedure the main block of _reconstructed/BOMBKI.PAS becomes in the
 * copy tools/android/make_library.py writes for the library build. */
#define GAME_ENTRY "BombkiMain"

/* What the child writes to the fail pipe when it cannot start
 * the game. A successful start closes the pipe instead, so the
 * parent sees EOF exactly when the game is running. */
struct child_failure {
    int step;
    int err;
    /* The child's own words: strerror(errno) or dlerror(), so the
     * parent can relay the reason verbatim. */
    char message[512];
};

/* Steps the child can fail in, so the parent can name the
 * operation rather than only the errno. */
enum {
    CHILD_STEP_SETCTTY = 1,
    CHILD_STEP_REMAP,
    CHILD_STEP_CHDIR,
    CHILD_STEP_LOAD,
    CHILD_STEP_FIND
};

static const char *step_name(int step) {
    switch (step) {
    case CHILD_STEP_SETCTTY:
        return "making the pty the controlling terminal";
    case CHILD_STEP_REMAP:
        return "connecting the pty to the game's standard streams";
    case CHILD_STEP_CHDIR:
        return "entering the working directory";
    case CHILD_STEP_LOAD:
        return "loading the game library";
    case CHILD_STEP_FIND:
        return "locating the game's entry point";
    default:
        return "starting the game";
    }
}

static void raise_error(JNIEnv *env, const char *message) {
    jclass error = (*env)->FindClass(env, "java/io/IOException");
    if (error != NULL) {
        (*env)->ThrowNew(env, error, message);
    }
}

static void raise_io_error(JNIEnv *env, const char *what) {
    char message[256];
    snprintf(message, sizeof(message), "%s failed: %s", what, strerror(errno));
    raise_error(env, message);
}

/* The game plays in 80x25; tell the pty that so the CRT sizes itself. */
static void set_window_size(int fd, int columns, int rows) {
    struct winsize size;
    memset(&size, 0, sizeof(size));
    size.ws_col = (unsigned short)columns;
    size.ws_row = (unsigned short)rows;
    /* Failure is not fatal: the game falls back to its own default size. */
    (void)ioctl(fd, TIOCSWINSZ, &size);
}

/**
 * Starts the game library on a new pty. Returns the child's pid, or -1 on
 * failure; the master fd is stored in outMasterFd[0] so the caller can
 * read and write it. Blocks until the child has either started the game
 * or failed, so a failed launch is reported here rather than surfacing
 * later as a silent exit.
 */
JNIEXPORT jint JNICALL
Java_io_github_fyiuramron_BombkiPty_00024Native_start(JNIEnv *env, jclass clazz,
                                                    jstring library, jstring workingDirectory,
                                                    jint columns, jint rows,
                                                    jintArray outMasterFd) {
    (void)clazz;

    const char *path = (*env)->GetStringUTFChars(env, library, NULL);
    if (path == NULL) {
        return -1;
    }
    const char *directory = (*env)->GetStringUTFChars(env, workingDirectory, NULL);
    if (directory == NULL) {
        (*env)->ReleaseStringUTFChars(env, library, path);
        return -1;
    }

    int master = open("/dev/ptmx", O_RDWR | O_NOCTTY);
    if (master < 0) {
        raise_io_error(env, "open(/dev/ptmx)");
        goto fail;
    }

    int unlock = 0;
    if (ioctl(master, TIOCSPTLCK, &unlock) < 0) {
        raise_io_error(env, "ioctl(TIOCSPTLCK)");
        close(master);
        goto fail;
    }

    int number = 0;
    if (ioctl(master, TIOCGPTN, &number) < 0) {
        raise_io_error(env, "ioctl(TIOCGPTN)");
        close(master);
        goto fail;
    }

    char slave_path[64];
    snprintf(slave_path, sizeof(slave_path), "/dev/pts/%d", number);
    int slave = open(slave_path, O_RDWR | O_NOCTTY);
    if (slave < 0) {
        raise_io_error(env, "open(/dev/pts/N)");
        close(master);
        goto fail;
    }

    set_window_size(slave, columns, rows);

    /* O_CLOEXEC on both ends is harmless now that there is no exec: the
     * child simply closes its write end once the game starts. */
    int fail_pipe[2];
    if (pipe2(fail_pipe, O_CLOEXEC) < 0) {
        raise_io_error(env, "pipe2");
        close(master);
        close(slave);
        goto fail;
    }

    pid_t pid = fork();
    if (pid < 0) {
        raise_io_error(env, "fork");
        close(master);
        close(slave);
        close(fail_pipe[0]);
        close(fail_pipe[1]);
        goto fail;
    }

    if (pid == 0) {
        /* Child: everything up to the game's entry point can fail, and
         * every failure is reported through the pipe. Formatting the
         * reason here is not strictly async-signal-safe, but the
         * alternative is a bare errno, and dlopen's dlerror() string
         * only exists in this process. */
#define REPORT_AND_EXIT(which, detail) \
        do { \
            struct child_failure failure; \
            memset(&failure, 0, sizeof(failure)); \
            failure.step = (which); \
            failure.err = errno; \
            snprintf(failure.message, sizeof(failure.message), "%s", (detail)); \
            (void)write(fail_pipe[1], &failure, sizeof(failure)); \
            _exit(127); \
        } while (0)

        (void)setsid();
        if (ioctl(slave, TIOCSCTTY, 0) < 0) {
            REPORT_AND_EXIT(CHILD_STEP_SETCTTY, strerror(errno));
        }
        if (dup2(slave, STDIN_FILENO) < 0 || dup2(slave, STDOUT_FILENO) < 0 ||
            dup2(slave, STDERR_FILENO) < 0) {
            REPORT_AND_EXIT(CHILD_STEP_REMAP, strerror(errno));
        }
        if (slave > STDERR_FILENO) {
            close(slave);
        }
        close(master);
        close(fail_pipe[0]);
        if (chdir(directory) < 0) {
            REPORT_AND_EXIT(CHILD_STEP_CHDIR, strerror(errno));
        }
        /* The game is a library, not an executable: dlopen is the one
         * launch path Android itself relies on (JNI), so device
         * security policy does not refuse it the way it can refuse
         * execve of a file under the app's data directory. */
        void *game = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        if (game == NULL) {
            REPORT_AND_EXIT(CHILD_STEP_LOAD, dlerror());
        }
        void (*entry)(void);
        *(void **)(&entry) = dlsym(game, GAME_ENTRY);
        if (entry == NULL) {
            REPORT_AND_EXIT(CHILD_STEP_FIND, dlerror());
        }
        /* The game owns the child from here on: close the pipe so the
         * parent sees EOF and knows the game is running. */
        close(fail_pipe[1]);
        entry();
        _exit(0);
#undef REPORT_AND_EXIT
    }

    close(slave);
    close(fail_pipe[1]);

    /* Blocks until the child starts the game (EOF) or reports a
     * failure. The child's single write is smaller than the pipe's
     * atomic write size, so one read gets all of it; the loop only
     * guards against a short read. */
    struct child_failure failure;
    memset(&failure, 0, sizeof(failure));
    ssize_t reported = 0;
    while (reported < (ssize_t)sizeof(failure)) {
        ssize_t chunk = read(fail_pipe[0], (char *)&failure + reported,
                             sizeof(failure) - reported);
        if (chunk <= 0) {
            break;
        }
        reported += chunk;
    }
    close(fail_pipe[0]);
    if (reported == (ssize_t)sizeof(failure)) {
        char detail[768];
        snprintf(detail, sizeof(detail), "%s: %s",
                 step_name(failure.step), failure.message);
        raise_error(env, detail);
        close(master);
        goto fail;
    }

    jint master_fd = (jint)master;
    (*env)->SetIntArrayRegion(env, outMasterFd, 0, 1, &master_fd);
    (*env)->ReleaseStringUTFChars(env, library, path);
    (*env)->ReleaseStringUTFChars(env, workingDirectory, directory);
    return (jint)pid;

fail:
    (*env)->ReleaseStringUTFChars(env, library, path);
    if (directory != NULL) {
        (*env)->ReleaseStringUTFChars(env, workingDirectory, directory);
    }
    return -1;
}

JNIEXPORT jint JNICALL
Java_io_github_fyiuramron_BombkiPty_00024Native_read(JNIEnv *env, jclass clazz,
                                                   jint fd, jbyteArray buffer) {
    (void)clazz;

    jsize length = (*env)->GetArrayLength(env, buffer);
    jbyte *bytes = (*env)->GetByteArrayElements(env, buffer, NULL);
    if (bytes == NULL) {
        return -1;
    }

    /* Poll first: closing the master fd does not reliably wake a blocked read,
     * so the timeout is what lets the reader thread notice it should stop.
     * Returns the byte count, 0 when the timeout expired with nothing to read,
     * or -1 once the game has closed its end (read then reports EOF). */
    struct pollfd waiter;
    waiter.fd = (int)fd;
    waiter.events = POLLIN;
    waiter.revents = 0;
    int ready = poll(& waiter, 1, 200);
    jint result = 0;
    if (ready > 0) {
        ssize_t count = read((int)fd, bytes, (size_t)length);
        result = count > 0 ? (jint)count : -1;
    } else if (ready < 0) {
        result = -1;
    }

    (*env)->ReleaseByteArrayElements(env, buffer, bytes, 0);
    return result;
}

JNIEXPORT jint JNICALL
Java_io_github_fyiuramron_BombkiPty_00024Native_write(JNIEnv *env, jclass clazz,
                                                    jint fd, jbyteArray buffer) {
    (void)clazz;

    jsize length = (*env)->GetArrayLength(env, buffer);
    jbyte *bytes = (*env)->GetByteArrayElements(env, buffer, NULL);
    if (bytes == NULL) {
        return -1;
    }
    ssize_t count = write((int)fd, bytes, (size_t)length);
    (*env)->ReleaseByteArrayElements(env, buffer, bytes, JNI_ABORT);
    return (jint)count;
}

/* Reaps the game and returns its exit status, or -1 while it is still alive.
 * A game killed by a signal comes back as 128 + the signal number. */
JNIEXPORT jint JNICALL
Java_io_github_fyiuramron_BombkiPty_00024Native_awaitExit(JNIEnv *env, jclass clazz, jint pid) {
    (void)env;
    (void)clazz;

    int status = 0;
    pid_t result = waitpid((pid_t)pid, &status, WNOHANG);
    if (result == 0) {
        return -1;
    }
    if (result < 0) {
        return -1;
    }
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    if (WIFSIGNALED(status)) {
        return 128 + WTERMSIG(status);
    }
    return -1;
}

JNIEXPORT void JNICALL
Java_io_github_fyiuramron_BombkiPty_00024Native_close(JNIEnv *env, jclass clazz, jint fd) {
    (void)env;
    (void)clazz;
    (void)close((int)fd);
}
