package io.github.fyiuramron;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * Hosts the reconstructed BOMBKI text-mode game.
 *
 * The game itself is the FPC-built Android arm64 shared library
 * (libbombki.so) that the package ships under lib/. It is an
 * interactive text-mode program, so it runs inside a pseudo
 * terminal (pty) provided by {@link BombkiPty}: the pty child
 * loads the library with dlopen and calls its entry point with
 * the pty as its standard streams. Output and stderr are
 * streamed into an xterm.js terminal rendered in a WebView, and
 * key presses travel back the other way as stdin bytes.
 */
public final class MainActivity extends Activity {

    private static final int REQUEST_RECORD_AUDIO = 1;

    private WebView terminal;
    private BombkiPty session;
    private VoiceInput voice;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING);

        terminal = new WebView(this);
        WebSettings settings = terminal.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setSupportZoom(false);
        settings.setBuiltInZoomControls(false);
        settings.setTextZoom(100);
        settings.setCacheMode(WebSettings.LOAD_NO_CACHE);
        terminal.setWebViewClient(new WebViewClient());
        terminal.setBackgroundColor(0xFF000000);
        terminal.setFocusable(true);
        terminal.setFocusableInTouchMode(true);
        terminal.requestFocus();
        setContentView(terminal);

        session = new BombkiPty(this, terminal);
        voice = new VoiceInput(this, terminal);
        terminal.addJavascriptInterface(new TerminalBridge(), "BombkiAndroid");
        terminal.loadUrl("file:///android_asset/terminal.html");

        // Voice is on by default, so ask for the microphone up front: the
        // prompt lands on top of the game rather than behind it, and a
        // refusal just leaves the keyboard as the input path.
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] {Manifest.permission.RECORD_AUDIO},
                    REQUEST_RECORD_AUDIO);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions,
                                           int[] results) {
        super.onRequestPermissionsResult(requestCode, permissions, results);
        if (requestCode == REQUEST_RECORD_AUDIO) {
            // Whether or not it was granted, recognition only starts once
            // the page is up and asks; this just records the outcome.
            voice.setGranted(results.length > 0
                    && results[0] == PackageManager.PERMISSION_GRANTED);
        }
    }

    /** Bridge the terminal page uses to push keystrokes into the game's stdin. */
    private final class TerminalBridge {
        @JavascriptInterface
        public void sendInput(String base64) {
            session.sendInput(base64);
        }

        /** The page calls this once xterm.js is open; everything the game
         * printed before then is replayed from Java's buffer. */
        @JavascriptInterface
        public void ready() {
            session.ready();
        }

        /** The in-page mic button: start recognising speech as input. */
        @JavascriptInterface
        public void startVoice() {
            voice.setWanted(true);
        }

        /** The in-page mic button again: stop and hand input back to the keys. */
        @JavascriptInterface
        public void stopVoice() {
            voice.setWanted(false);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        session.attach();
        voice.resume();
    }

    @Override
    protected void onPause() {
        // Recognition holds the microphone; releasing it when the activity
        // is not visible keeps it from recording a pocket.
        voice.pause();
        session.detach();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        session.close();
        voice.release();
        super.onDestroy();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus && terminal != null) {
            terminal.requestFocus();
        }
    }

    /** Android back button: ask the terminal page to handle it first (xterm.js). */
    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (terminal != null && keyCode == KeyEvent.KEYCODE_BACK) {
            terminal.evaluateJavascript("window.__bombkiBack && window.__bombkiBack()", null);
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }
}