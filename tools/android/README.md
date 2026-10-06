# BOMBKI Android wrapper

Packaging sources for the APK built by `tools/build_apk.py`, plus the script
that rewrites the reconstructed game into the library the APK loads. This is
not a standalone application project: there is no Gradle setup, and `app/` and
`native/` are built only by `tools/build_apk.py`. The layout mirrors a project
only so the sources are easy to browse.

- `app/src/main/AndroidManifest.xml` - activity and packaging, `minSdk 21`
- `app/src/main/java/io/github/fyiuramron/` - the launcher
- `app/src/main/res/` - app label, theme, launcher icon
- `app/src/main/assets/terminal.html` - xterm.js front end
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
