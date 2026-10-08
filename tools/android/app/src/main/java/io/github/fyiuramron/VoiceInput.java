package io.github.fyiuramron;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.util.Base64;
import android.util.Log;
import android.webkit.WebView;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;

/**
 * Turns speech into keystrokes for the reconstructed game.
 *
 * <p>BOMBKI is a 1999 Turbo Pascal program that compares every command
 * against an uppercase literal and never trims what it read, so a lowercase
 * letter or a diacritic makes a command silently do nothing. Voice input
 * produces exactly that, so it is normalised on the terminal page rather
 * than here: the page owns the folding and the spoken-ENTER rule, and this
 * class only delivers recognised text as {@code window.__bombkiSay}, base64
 * encoded for the same reason game output is - {@code evaluateJavascript}
 * takes UTF-8 strings and recogniser text is not guaranteed to be shaped
 * the way a JS string literal would need it to be.
 *
 * <p>Recognition is continuous by design: a command line game is played as a
 * stream of utterances, and {@code SpeechRecognizer} delivers one result per
 * utterance. Sessions are restarted after each result or error, because the
 * service ends them itself after a pause; the toggle in the page is what
 * turns this off.
 *
 * <p>Android WebView has no Web Speech API, so this has to be Java.
 *
 * <p><b>To swap in Vosk instead</b> (offline, no session restarts, at the
 * cost of roughly 40&nbsp;MB for the native library plus the Polish model):
 * replace this class with an {@code AudioRecord} loop feeding a Vosk
 * {@code Recognizer} - it still only needs to call {@code say()}, so the
 * terminal page and its input filter do not change. The model then has to be
 * shipped under {@code app/src/main/assets/} (Vosk reads it as files from
 * disk, so it is extracted to app storage on first run), and
 * {@code tools/build_apk.py} needs the AAR's {@code classes.jar} on the
 * javac classpath and its {@code lib/} native libraries in the APK - it
 * currently compiles the sources against {@code android.jar} alone.
 */
final class VoiceInput implements RecognitionListener {

    private static final String TAG = "BombkiVoice";

    private static final int NO_LANGUAGE = 0;

    /** Matches RecognizerIntent.ACTION_RECOGNIZE_SPEECH. */
    private static final String ACTION_RECOGNIZE = "android.speech.action.RECOGNIZE_SPEECH";

    private final WebView terminal;

    /** SpeechRecognizer is only usable from the thread that made it. */
    private SpeechRecognizer recognizer;

    /**
     * Language the commands are transcribed in. BOMBKI is a Polish
     * game: every command it accepts is a Polish word, so a
     * recogniser working in the device default - often English,
     * since that is what most devices ship with - misses every
     * command it hears. Without this extra the input is useless.
     */
    private static final String VOICE_LANGUAGE = "pl-PL";

    /** What the page's toggle asked for; recognition chases this. */
    private boolean wanted;

    /** Mic permission outcome, as reported by the activity. */
    private boolean granted;

    /** Recognition must not be resumed while the activity is in the background. */
    private boolean resumed;

    /** Recognition ends itself after a pause; this is what restarts it. */
    private final Runnable restart = new Runnable() {
        @Override
        public void run() {
            if (wanted && resumed && recognizer != null) {
                begin();
            }
        }
    };

    VoiceInput(Context context, WebView terminal) {
        this.terminal = terminal;
        if (SpeechRecognizer.isRecognitionAvailable(context)) {
            recognizer = SpeechRecognizer.createSpeechRecognizer(context);
            recognizer.setRecognitionListener(this);
        } else {
            Log.w(TAG, "no speech recognition service; the keyboard stays the input path");
        }
    }

    /** The page's toggle. Safe to call before the activity is resumed. */
    void setWanted(boolean wanted) {
        this.wanted = wanted;
        if (!wanted) {
            stopListening();
        } else if (resumed) {
            // The page turns itself on at load, which can beat the
            // permission result; re-reading it here is harmless.
            begin();
        }
    }

    void setGranted(boolean granted) {
        this.granted = granted;
    }

    void resume() {
        resumed = true;
        if (wanted) {
            begin();
        }
    }

    void pause() {
        resumed = false;
        stopListening();
    }

    void release() {
        stopListening();
        if (recognizer != null) {
            recognizer.destroy();
            recognizer = null;
        }
    }

    private void begin() {
        if (recognizer == null) {
            return;
        }
        Intent request = new Intent(ACTION_RECOGNIZE)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                          RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, VOICE_LANGUAGE)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE,
                          VOICE_LANGUAGE)
                .putExtra(RecognizerIntent.EXTRA_PROFANITY_FILTER, false)
                .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
        try {
            recognizer.startListening(request);
        } catch (RuntimeException error) {
            // startListening throws if it is called while already listening,
            // which the restart below can race with.
            Log.w(TAG, "startListening was refused", error);
        }
    }

    private void stopListening() {
        if (recognizer == null) {
            return;
        }
        try {
            recognizer.stopListening();
        } catch (RuntimeException error) {
            Log.w(TAG, "stopListening was refused", error);
        }
    }

    /** Hands a finished phrase to the page's filter. */
    private void say(String text) {
        String encoded = Base64.encodeToString(text.getBytes(StandardCharsets.UTF_8),
                                               Base64.NO_WRAP);
        terminal.post(() -> terminal.evaluateJavascript(
                "window.__bombkiSay && window.__bombkiSay('" + encoded + "')", null));
    }

    private void keepGoing() {
        // Restart on the next loop rather than straight away: the recogniser
        // service is still tearing the previous session down.
        terminal.postDelayed(restart, 250);
    }

    @Override
    public void onResults(Bundle results) {
        ArrayList<String> matches =
                results == null ? null : results.getStringArrayList(
                        SpeechRecognizer.RESULTS_RECOGNITION);
        if (matches != null && !matches.isEmpty()) {
            say(matches.get(0));
        }
        keepGoing();
    }

    @Override
    public void onReadyForSpeech(Bundle params) {
        Log.d(TAG, "ready for speech");
    }

    @Override
    public void onBeginningOfSpeech() {
    }

    @Override
    public void onRmsChanged(float rms) {
    }

    @Override
    public void onBufferReceived(byte[] buffer) {
    }

    @Override
    public void onEndOfSpeech() {
    }

    @Override
    public void onPartialResults(Bundle partial) {
        // Partial results are switched off in begin(): they would append the
        // same words repeatedly as each interim guess replaces the last.
    }

    @Override
    public void onEvent(int type, Bundle params) {
    }

    @Override
    public void onError(int code) {
        // No-match and timeout are the normal end of an utterance, and the
        // service reports them as errors; anything else is logged. Either
        // way, an active toggle restarts the session.
        if (code != SpeechRecognizer.ERROR_NO_MATCH
                && code != SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
            Log.w(TAG, "recognition error " + code);
        }
        keepGoing();
    }
}