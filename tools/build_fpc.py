#!/usr/bin/env python3
"""Build BOMBKI with FPC in TP mode: x86_64 Linux and Win64
executables, and the Android arm64 game library the APK loads
with dlopen.

Run on either Linux or Windows with FPC installed and available as ``fpc``
(or selected with ``--fpc`` / ``FPC``). The non-host targets also need their FPC
RTL units and cross-binutils; ``tools/setup_fpc_windows_cross.sh`` and
``tools/setup_fpc_android_cross.sh`` configure those. Use ``--run`` to launch the
host-native result.

Android is the one target whose source is not the reconstructed program as
written: the game has to be a shared library there, so ``BOMBKI.PAS`` is first
rewritten into that shape by ``tools/android/make_library.py``, and only the
android build runs the copy. Every other target compiles
``_reconstructed/BOMBKI.PAS`` unchanged.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
SOURCES = PROJECT / "_reconstructed"
TEMP_ROOT = PROJECT / "build" / "tmp"
ANDROID = Path(__file__).resolve().parent / "android"
MAKE_LIBRARY = ANDROID / "make_library.py"
UNIT_NAMES = ("MONSTRA", "PRZEDM", "SWIAT")
PROGRAM_NAME = "BOMBKI"


def resolve_executable(name: str) -> str:
    resolved = shutil.which(name)
    if resolved:
        return resolved
    path = Path(name).expanduser()
    if path.is_file():
        return str(path.resolve())
    raise FileNotFoundError(f"FPC executable not found: {name}")


TARGET_FLAGS = {
    "linux": ("-Tlinux", "-Px86_64"),
    "windows": ("-Twin64", "-Px86_64"),
    "android": ("-Tandroid", "-Paarch64"),
}
DEFAULT_CROSS_PREFIX = {
    "linux": "x86_64-linux-",
    "windows": "x86_64-w64-mingw32-",
    "android": "aarch64-linux-android21-",
}
# Target architecture label used in artifact names, and the ABI directory the
# binary is installed under inside an APK.
TARGET_ARCH = {
    "linux": "x86_64",
    "windows": "x86_64",
    "android": "arm64-v8a",
}
# Built when no --target is given. Android is left out on purpose: it needs an
# NDK, so it must be asked for explicitly.
DEFAULT_TARGETS = ("linux", "windows")


def android_library_source(build_dir: Path) -> Path:
    # Android needs the game as a loadable library (BombkiMain, called by the
    # pty child), not as an executable, so the main block is rewritten into an
    # exported procedure by tools/android/make_library.py. The reconstructed
    # source is left alone; only the copy is compiled. It keeps the original
    # file name in its own directory because FPC names the library after it.
    patched_dir = build_dir / "android-src"
    patched_dir.mkdir(parents=True, exist_ok=True)
    patched = patched_dir / f"{PROGRAM_NAME}.PAS"
    command = [sys.executable, str(MAKE_LIBRARY), str(SOURCES / f"{PROGRAM_NAME}.PAS"),
               "-o", str(patched)]
    print("+", subprocess.list2cmdline(command))
    subprocess.run(command, check=True)
    return patched


def find_program(directory: Path, target: str) -> Path:
    if target == "android":
        # Built as a library (the BombkiMain entry point the
        # pty child calls), so FPC names it the way ELF expects.
        names = ("libBOMBKI.so", "BOMBKI.so")
    elif target == "windows":
        names = ("BOMBKI.exe", "BOMBKI")
    else:
        names = ("BOMBKI", "BOMBKI.exe")
    for name in names:
        candidate = directory / name
        if candidate.is_file() and candidate.stat().st_size:
            return candidate
    raise FileNotFoundError(f"FPC did not produce a nonempty BOMBKI binary in {directory}")


def artifact_name(target: str) -> str:
    if target == "windows":
        return f"BOMBKI-{target}-{TARGET_ARCH[target]}.exe"
    if target == "android":
        # The game library the APK packages under lib/.
        return f"BOMBKI-{target}-{TARGET_ARCH[target]}.so"
    return f"BOMBKI-{target}-{TARGET_ARCH[target]}"


def host_target() -> str:
    if sys.platform == "win32":
        return "windows"
    if sys.platform.startswith("linux"):
        return "linux"
    raise RuntimeError("build_fpc.py supports Linux and Windows hosts")


def cross_prefix(target: str, host: str, args: argparse.Namespace) -> str | None:
    if target == host:
        return None
    option = getattr(args, f"{target}_cross_prefix")
    if option:
        return option
    environment = os.environ.get(f"FPC_{target.upper()}_CROSS_PREFIX")
    return environment or DEFAULT_CROSS_PREFIX[target]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fpc", default=os.environ.get("FPC", "fpc"),
                        help="FPC executable (default: FPC env var or fpc)")
    parser.add_argument("--target", choices=tuple(TARGET_FLAGS), action="append",
                        dest="targets",
                        help="target to build; repeat for several (default: linux and windows)")
    parser.add_argument("--linux-cross-prefix",
                        help="binutils prefix for a non-native Linux target (or FPC_LINUX_CROSS_PREFIX)")
    parser.add_argument("--windows-cross-prefix",
                        help="binutils prefix for a non-native Windows target (or FPC_WINDOWS_CROSS_PREFIX)")
    parser.add_argument("--android-cross-prefix",
                        help="binutils prefix for the Android target (or FPC_ANDROID_CROSS_PREFIX)")
    parser.add_argument("--output-dir", type=Path,
                        default=PROJECT / "build" / "fpc",
                        help="directory for both executables (default: build/fpc)")
    parser.add_argument("--run", action="store_true",
                        help="run the host-native executable after building both targets")
    args = parser.parse_args()

    try:
        host = host_target()
        targets = args.targets or [host, *(target for target in DEFAULT_TARGETS if target != host)]
        if args.run and host not in targets:
            parser.error(f"--run requires the host target ({host}) to be included")
        fpc = resolve_executable(args.fpc)
        output_dir = args.output_dir.expanduser().resolve()
        output_dir.mkdir(parents=True, exist_ok=True)
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        print(f"FPC: {subprocess.check_output([fpc, '-iV'], text=True).strip()}")
        built: dict[str, Path] = {}
        for target in targets:
            prefix = cross_prefix(target, host, args)
            with tempfile.TemporaryDirectory(prefix=f"bombki-fpc-{target}-",
                                             dir=TEMP_ROOT) as temporary:
                build_dir = Path(temporary)
                target_options = list(TARGET_FLAGS[target])
                if prefix:
                    target_options.append(f"-XP{prefix}")
                print(f"Building {target} {TARGET_ARCH[target]}...")
                for name in (*UNIT_NAMES, PROGRAM_NAME):
                    source = SOURCES / f"{name}.PAS"
                    if target == "android" and name == PROGRAM_NAME:
                        source = android_library_source(build_dir)
                    command = [
                        fpc, "-B", "-Mtp", *target_options,
                        f"-Fu{SOURCES}", f"-Fu{build_dir}",
                        f"-FU{build_dir}", f"-FE{build_dir}",
                        str(source),
                    ]
                    print("+", subprocess.list2cmdline(command))
                    try:
                        subprocess.run(command, cwd=build_dir, check=True)
                    except subprocess.CalledProcessError as error:
                        if prefix:
                            detail = (
                                "Cross builds need the target RTL units and "
                                "assembler/linker; configure the binutils prefix "
                                f"with --{target}-cross-prefix if needed."
                            )
                        else:
                            detail = "Check the FPC installation and compiler output above."
                        raise RuntimeError(
                            f"FPC failed building {target} {TARGET_ARCH[target]}. {detail}"
                        ) from error

                binary = find_program(build_dir, target)
                destination = output_dir / artifact_name(target)
                shutil.copy2(binary, destination)
                built[target] = destination
                print(f"Built {destination} ({destination.stat().st_size} bytes)")

        if args.run:
            return subprocess.run([str(built[host])], cwd=output_dir).returncode
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"build_fpc.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
