#!/usr/bin/env python3
"""Package the Android arm64 BOMBKI game library into a signed debug APK.

The APK holds the game's terminal wrapper (see ``tools/android/``): a WebView running
xterm.js in front of a pseudo terminal whose child loads the FPC-built game library
(libbombki.so, shipped under ``lib/``) with dlopen.

Requires the Android SDK (platform + build-tools) and an NDK for the JNI helper,
discoverable via ``ANDROID_HOME``/``ANDROID_SDK_ROOT`` and
``ANDROID_NDK_ROOT``/``ANDROID_NDK_HOME`` or the matching command line options.
Signing uses ``--keystore``; when the keystore is absent, a throwaway debug
keystore is generated (and reused on later runs) under ``build/apk``.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
ANDROID = Path(__file__).resolve().parent / "android"
RES = ANDROID / "app/src/main/res"
ASSETS = ANDROID / "app/src/main/assets"
JAVA = ANDROID / "app/src/main/java"
MANIFEST = ANDROID / "app/src/main/AndroidManifest.xml"
NATIVE = ANDROID / "native" / "pty.c"
BUILD = PROJECT / "build" / "apk"
OUTPUT = PROJECT / "build" / "android"
DEFAULT_KEYSTORE = BUILD / "debug.keystore"
GAME_LIBRARY = "bombki"
GAME_SONAME = f"lib{GAME_LIBRARY}.so"
NATIVE_LIB = "bombkipty"

ABI = "arm64-v8a"
MIN_SDK = 21
TARGET_SDK = 34
KEY_ALIAS = "androiddebugkey"
KEY_PASSWORD = "android"
KEY_DN = "CN=BOMBKI Debug,O=BOMBKI,C=PL"


class BuildError(RuntimeError):
    """A build step failed or a required tool is missing."""


def java_environment() -> dict[str, str]:
    """Puts the JDK on PATH, which the d8/apksigner shell wrappers need."""
    environment = dict(os.environ)
    home = java_tool("java").parent.parent
    existing = environment.get("PATH", "")
    environment["PATH"] = f"{home / 'bin'}:{existing}" if existing else str(home / "bin")
    environment.setdefault("JAVA_HOME", str(home))
    return environment


def run(command: list[str]) -> subprocess.CompletedProcess:
    print("+", subprocess.list2cmdline(command), flush=True)
    try:
        return subprocess.run(command, check=True, env=java_environment())
    except FileNotFoundError as error:
        raise BuildError(f"{command[0]} not found: {error}") from error
    except subprocess.CalledProcessError as error:
        raise BuildError(f"{command[0]} failed with exit status {error.returncode}") from error


def version_key(name: str) -> list[tuple[int, object]]:
    # Tag each part so that a number never sorts against a string:
    # "android-34" and "34.0.0" both end up in a stable order.
    return [(0, int(part)) if part.isdigit() else (1, part)
            for part in name.replace("-", ".").split(".") if part]


def newest_dir(root: Path) -> Path | None:
    if not root.is_dir():
        return None
    candidates = sorted((child for child in root.iterdir() if child.is_dir()), key=lambda c: version_key(c.name))
    return candidates[-1] if candidates else None


def find_sdk(explicit: str | None) -> Path:
    candidates = [explicit, os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT"),
                  os.environ.get("ANDROID_SDK"), "~/Android/Sdk", "/opt/android-sdk", "/usr/lib/android-sdk"]
    for candidate in candidates:
        if not candidate:
            continue
        path = Path(candidate).expanduser()
        if (path / "platforms").is_dir() and (path / "build-tools").is_dir():
            return path.resolve()
    raise BuildError("Android SDK with platforms/ and build-tools/ not found; set ANDROID_HOME or pass --android-sdk")


def find_ndk(explicit: str | None, sdk: Path) -> Path:
    for candidate in (explicit, os.environ.get("ANDROID_NDK_ROOT"), os.environ.get("ANDROID_NDK_HOME")):
        if candidate and (Path(candidate) / "toolchains/llvm/prebuilt").is_dir():
            return Path(candidate).resolve()
    ndk = newest_dir(sdk / "ndk")
    if ndk is not None and (ndk / "toolchains/llvm/prebuilt").is_dir():
        return ndk.resolve()
    raise BuildError("Android NDK not found; set ANDROID_NDK_ROOT or pass --ndk")


def android_jar(sdk: Path) -> Path:
    platform = newest_dir(sdk / "platforms")
    if platform is None or not (platform / "android.jar").is_file():
        raise BuildError(f"no android.jar under {sdk / 'platforms'}")
    return platform / "android.jar"


def build_tools(sdk: Path) -> Path:
    tools = newest_dir(sdk / "build-tools")
    if tools is None:
        raise BuildError(f"no build-tools under {sdk}")
    return tools


def ndk_clang(ndk: Path) -> Path:
    prebuilt = ndk / "toolchains/llvm/prebuilt"
    for host in sorted((child for child in prebuilt.iterdir() if child.is_dir()),
                       key=lambda child: child.name, reverse=True):
        clang = host / "bin" / "clang"
        if clang.is_file():
            return clang
    raise BuildError(f"no NDK clang found under {prebuilt}")


def java_tool(name: str) -> Path:
    java_home = os.environ.get("JAVA_HOME")
    roots = [Path(java_home)] if java_home else []
    roots += [Path("/usr/lib/jvm/default-java"), Path("/usr/lib/jvm/java-17-openjdk-amd64")]
    for root in roots:
        candidate = root / "bin" / name
        if candidate.is_file():
            return candidate.resolve()
    found = shutil.which(name)
    if found:
        return Path(found)
    raise BuildError(f"{name} not found; install a JDK 17+ or set JAVA_HOME")


def compile_resources(sdk: Path, work: Path) -> Path:
    aapt2 = build_tools(sdk) / "aapt2"
    # Compiling with a directory target keeps the .flat container format aapt2
    # expects on link; naming a single output file yields a zip instead.
    flat_dir = work / "flat"
    flat_dir.mkdir(parents=True, exist_ok=True)
    sources = sorted(RES.rglob("*.xml"))
    run([str(aapt2), "compile", "-o", str(flat_dir), *[str(path) for path in sources]])
    linked = work / "resources.apk"
    command = [str(aapt2), "link",
               "--manifest", str(MANIFEST),
               "-I", str(android_jar(sdk)),
               "--min-sdk-version", str(MIN_SDK),
               "--target-sdk-version", str(TARGET_SDK),
               "--version-code", "1",
               "--version-name", "1.0",
               "-o", str(linked),
               *[str(path) for path in sorted(flat_dir.glob("*.flat"))]]
    run(command)
    return linked


def compile_java(sdk: Path, work: Path) -> Path:
    sources = sorted(JAVA.rglob("*.java"))
    classes = work / "classes"
    classes.mkdir(parents=True, exist_ok=True)
    javac = java_tool("javac")
    run([str(javac), "-nowarn", "-encoding", "UTF-8", "--release", "17",
         "-classpath", str(android_jar(sdk)), "-d", str(classes),
         *[str(path) for path in sources]])
    return classes


def compile_dex(sdk: Path, work: Path, classes: Path) -> Path:
    jar = java_tool("jar")
    archive = work / "classes.jar"
    run([str(jar), "--create", "--file", str(archive), "-C", str(classes), "."])
    tools = build_tools(sdk)
    d8 = tools / "d8"
    if not d8.is_file():
        d8 = tools / "d8.bat"
    run([str(d8), "--min-api", str(MIN_SDK), "--lib", str(android_jar(sdk)),
         "--output", str(work), str(archive)])
    dex = work / "classes.dex"
    if not dex.is_file():
        raise BuildError("d8 did not produce classes.dex")
    return dex


def compile_native(ndk: Path, work: Path) -> Path:
    library = work / f"lib{NATIVE_LIB}.so"
    run([str(ndk_clang(ndk)), f"--target=aarch64-linux-android{MIN_SDK}",
         "-fPIC", "-shared", "-O2", "-o", str(library), str(NATIVE)])
    return library


def assemble(work: Path, linked: Path, dex: Path, native: Path, game: Path) -> Path:
    unsigned = work / "bombki-unsigned.apk"
    with zipfile.ZipFile(unsigned, "w") as archive:
        # aapt2's output carries the binary manifest and resource table, which
        # apksigner needs; copy it in wholesale rather than picking entries.
        with zipfile.ZipFile(linked) as resources:
            for name in resources.namelist():
                archive.writestr(name, resources.read(name))
        archive.write(dex, "classes.dex")
        for path in sorted(ASSETS.rglob("*")):
            if path.is_file():
                archive.write(path, f"assets/{path.relative_to(ASSETS).as_posix()}")
        # Both files belong in lib/: the installer extracts that
        # into the app's native library directory, and dlopen of
        # the app's own libraries is the launch path Android
        # itself relies on for JNI, so no device security policy
        # blocks it the way execve of a data-directory file can
        # be. The pty child loads the game and calls its
        # BombkiMain entry point with the pty on fds 0/1/2.
        archive.write(native, f"lib/{ABI}/lib{NATIVE_LIB}.so")
        archive.write(game, f"lib/{ABI}/{GAME_SONAME}")
    return unsigned


def ensure_keystore(keystore: Path) -> Path:
    if keystore.is_file():
        return keystore
    keystore.parent.mkdir(parents=True, exist_ok=True)
    run([str(java_tool("keytool")), "-genkeypair", "-noprompt", "-keystore", str(keystore),
         "-storepass", KEY_PASSWORD, "-keypass", KEY_PASSWORD, "-alias", KEY_ALIAS,
         "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", KEY_DN])
    return keystore


def sign(sdk: Path, work: Path, unsigned: Path, keystore: Path) -> Path:
    tools = build_tools(sdk)
    aligned = work / "bombki-aligned.apk"
    run([str(tools / "zipalign"), "-f", "-p", "4", str(unsigned), str(aligned)])
    OUTPUT.mkdir(parents=True, exist_ok=True)
    signed = OUTPUT / f"BOMBKI-debug-{ABI}.apk"
    apksigner = tools / "apksigner"
    run([str(apksigner), "sign", "--ks", str(keystore),
         "--ks-pass", f"pass:{KEY_PASSWORD}", "--key-pass", f"pass:{KEY_PASSWORD}",
         "--ks-key-alias", KEY_ALIAS, "--min-sdk-version", str(MIN_SDK),
         # The .idsig sidecar is only needed for incremental install; it would
         # otherwise be picked up alongside the APK by release tooling.
         "--v4-signing-enabled", "false",
         "--out", str(signed), str(aligned)])
    run([str(apksigner), "verify", "--print-certs", str(signed)])
    return signed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--android-sdk", help="Android SDK root (default: ANDROID_HOME)")
    parser.add_argument("--ndk", help="Android NDK root (default: ANDROID_NDK_ROOT)")
    parser.add_argument("--game", type=Path, default=PROJECT / f"build/fpc/BOMBKI-android-{ABI}.so",
                        help=f"Android game library to package (default: build/fpc/BOMBKI-android-{ABI}.so)")
    parser.add_argument("--keystore", type=Path, default=DEFAULT_KEYSTORE,
                        help="signing keystore; a debug one is generated when absent")
    parser.add_argument("--work-dir", type=Path, default=BUILD, help="APK work directory")
    args = parser.parse_args()

    try:
        game = args.game.expanduser().resolve()
        if not game.is_file() or not game.stat().st_size:
            raise BuildError(f"Android game library not found: {game}; build it first with "
                             "'tools/build_fpc.py --target android'")
        sdk = find_sdk(args.android_sdk)
        ndk = find_ndk(args.ndk, sdk)
        work = args.work_dir.expanduser().resolve()
        if work.exists():
            shutil.rmtree(work)
        work.mkdir(parents=True)
        print(f"Android SDK: {sdk}")
        print(f"Android NDK: {ndk}")
        print(f"Android API level: {MIN_SDK} (target {TARGET_SDK}, ABI {ABI})")

        linked = compile_resources(sdk, work)
        classes = compile_java(sdk, work)
        dex = compile_dex(sdk, work, classes)
        native = compile_native(ndk, work)
        unsigned = assemble(work, linked, dex, native, game)
        keystore = ensure_keystore(args.keystore.expanduser().resolve())
        signed = sign(sdk, work, unsigned, keystore)
        print(f"Built {signed} ({signed.stat().st_size} bytes)")
    except (BuildError, OSError, subprocess.CalledProcessError) as error:
        print(f"build_apk.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())