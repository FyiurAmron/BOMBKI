# BOMBKI Android wrapper

Packaging sources for the APK built by `tools/build_apk.py`, plus the script
that rewrites the reconstructed game into the library the APK loads. This is
not a standalone application project: there is no Gradle setup, and `app/` and
`native/` are built only by `tools/build_apk.py`. The layout mirrors a project
only so the sources are easy to browse.

- `app/src/main/AndroidManifest.xml` - activity and packaging, `minSdk 21`
- `app/src/main/java/io/github/fyiuramron/` - the launcher
- `app/src/main/res/` - app label, theme, launcher icon
- `app/src/main/assets/terminal.html` - xterm.js front end, input filter and mic toggle
- `native/pty.c` - pseudo terminal helper, compiled to `libbombkipty.so`
- `make_library.py` - writes the library build of `_reconstructed/BOMBKI.PAS`

## How the game is shipped

The game is the FPC-built shared library `libbombki.so`, packaged under
`lib/arm64-v8a/` next to the pty helper. The pty child loads it with
`dlopen` and calls its exported `BombkiMain`, which is the main block of
`_reconstructed/BOMBKI.PAS` turned into an exported procedure.

`_reconstructed/BOMBKI.PAS` is a plain Turbo Pascal program, and it stays
that way: the reconstruction describes the DOS executable, so nothing
Android-specific belongs in it. `make_library.py` rewrites a copy into
the library shape - `library` header, the main block wrapped in
`procedure BombkiMain`, `exports BombkiMain`, an empty main block - and
`tools/build_fpc.py --target android` compiles that copy, so only the
Android build is affected. The script locates the four anchors it moves
(program header, the main block's `label` declaration, the main block's
`begin`, the closing `end.`) and refuses to write anything if they are
not where it expects, rather than emitting a source that will not
compile. It can also be run by hand:

```sh
tools/android/make_library.py _reconstructed/BOMBKI.PAS -o /tmp/BOMBKI.PAS
```

The game is a library rather than an executable on purpose: `execve` of a
file under the app's data directory is refused by some devices' security
policy no matter what permissions the app sets (the game was tried as an
asset the app copies out and marks executable first - identical
"Permission denied" on every attempt), while `dlopen` of the app's own
libraries is the path Android itself uses for JNI, so no policy blocks it.
The fork still happens in C: the child needs the pty slave as its fds 0/1/2
and the library call to happen after that, and by the time Java sees a
`Process`, the descriptors are already fixed.

## Voice input

The game is a 1999 DOS program: it compares every command against an
uppercase literal and compares with `=`, so it neither uppercases what
it reads nor trims it. A lowercase letter, a diacritic or a trailing
space makes the command silently do nothing - the splash says
`KORZYSTAJ Z DUZYCH LITER` for exactly this reason. Voice input
produces all three, so the terminal page folds anything printable down
to `[A-Z0-9 .-]` before it reaches the game: diacritics are stripped
(`NFD` plus a small table for the letters that do not decompose, so
`ł` becomes `l`), everything is uppercased, and everything else is
dropped. The two punctuation marks are kept because the game's own
vocabulary uses them inside words - the `POL-ELF` race, `MINI-BARMAN`,
`D.J` - so stripping them would make one of the six races unreachable
at the very first prompt; no punctuation may lead the line or be
doubled, and trailing punctuation is backed out when a phrase ends.
One word is corrected outright: the game misprints its south
command in its own instructions, so a player typing what they read
sends `POLUDNIE`, which matches nothing. Once a word closes - a
space, the end of a phrase, an Enter - the filter erases it and
sends the `POLODNIE` the game accepts. The correction is visible
in the echo, but the game itself never sees the mistake; the
workaround can go when a later game release fixes the prompt.
The keyboard goes through the same path, so typing behaviour does not
change.

A spoken "ENTER" submits rather than typing itself. Voice appends to the
line the player has already spoken - there is no "before" in which to
remove it - so the letters do reach the game and are then backed out
with `BS`, which Crt honours as an erase and echoes as `BS SP`. The
separating space and any trailing punctuation go with them, because the
game does not trim. This is why the filter tracks the line it has sent
rather than only the current word: a trailing space has to be erased
before any Enter, and the count has to stay in step with the player's
own backspaces.

Voice also arrives as separate utterances, each returned with no
leading space, so a phrase that follows text already on the line is
preceded by one; without that, "dawaj" then "5 monet" reaches the game
as "DAWAJ5MONET", which is no command. Recognition is fixed to Polish
(`pl-PL`): the game's commands are Polish words, and a recogniser
working in the device default - often English - misses every command it
hears.

The toggle is a button in the top-right of the terminal, chosen because
the bottom of an 80x25 console is the live edge - prompt, newest output
and cursor - and the top row is the oldest content on screen. It is an
overlay rather than a strip so the pty keeps all 25 rows. It is driven
from `pointerdown` with `preventDefault` so a tap never blurs the
textarea xterm.js reads keystrokes from, which would dismiss the soft
keyboard mid-command. Voice is on by default and the microphone
permission is requested at startup; refusing it leaves the keyboard
working.

Android WebView has no Web Speech API, so `VoiceInput.java` wraps
`SpeechRecognizer` and hands each finished phrase to
`window.__bombkiSay`, base64 encoded for the same reason game output is.
Sessions are restarted after each result or error, since the service
ends them itself after a pause. Partial results are switched off: they
would append the same words again with every interim guess. Recognition
holds the microphone, so it is released when the activity is paused.
A Vosk build (offline, no session restarts) only replaces that one
class and the recognizer behind `__bombkiSay`; the class comment in
`VoiceInput.java` records what else such a build has to change.

## Scrolling

Drag scrolling is built into the viewport, as are the wheel and
PageUp/PageDown, but all of them stop at the last buffer line. On
a phone the bottom of a landscape 80x25 screen can sit under a
rounded corner or the on-screen keyboard, and the lines the player
needs are exactly the ones covered. So a drag that begins at the
bottom edge lifts the screen itself, up to 20 lines: the last
buffer line can then sit near the top of the screen, with blank
space below it.

The lift is a `translateY` on the screen element, not a scroll:
the buffer and the scroll position are left alone, so the viewport
keeps following live output and the lifted view simply moves with
it - which is the point, the player wants the newest line pinned
near the top while the game runs. xterm re-syncs `scrollTop` to
the buffer after every render, which is why the scroll position
cannot be used for this; a transform on the screen element is the
one thing it never touches. A lift only ever starts at the bottom
edge, gives way before the buffer scrolls again (the move is
captured on the container and kept from the viewport's own touch
handling while it lasts), and ends if the buffer scrolls up, so
the two can never fight. Dragging back down unwinds it and returns
to the live edge.

## Why the pty

The game is Turbo Pascal 7 code that drives the screen directly and reads one
keystroke at a time. `ProcessBuilder` pipes do not satisfy it, so
`native/pty.c` opens `/dev/ptmx` (bionic has no `forkpty()`) and forks the
child with the pty slave as its fds 0/1/2.

Output is raw CP437, which `evaluateJavascript` cannot carry as UTF-8, so bytes
travel to the terminal page base64-encoded.

## Why output is buffered

The game prints its splash screen as its very first output, which races
the WebView's page load: until the page has loaded, `evaluateJavascript`
runs against about:blank and every write is silently dropped. So
`BombkiPty` holds output in a buffer and replays it when the page calls
`BombkiAndroid.ready()` after xterm.js opens. The same buffer carries the
game's exit status and any launch error, so a failed start shows up as a
message rather than a blank screen.

A pipe in `native/pty.c` reports the child's errno: the child writes the
failing step, errno and a human-readable reason to it before `_exit(127)`,
while a successful start closes the pipe's write end instead, so the parent
sees EOF exactly when the game is running.

## Error reporting

A critical error (failed launch, game killed by a signal) prints a
diagnostic dump to the terminal itself - the screen the user is looking at -
rather than only to logcat: the failing step and reason, the game library's
path/size, package and APK paths, Android version, device fingerprint,
supported ABIs, the SELinux context, the mount options of every mount
holding the app's data (where a `noexec` policy would show), and an `execve`
probe that separates "exec is blocked outright" from "the data mount is
noexec". `BombkiPty.java` builds the dump; the game's own stdout and stderr
arrive through the pty as usual.

`assets/vendor/xterm.js` and `xterm.css` are xterm.js 5.5.0, MIT licensed,
fetched from the jsDelivr copy of the npm package.
