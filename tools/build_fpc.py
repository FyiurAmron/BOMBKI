#!/usr/bin/env python3
"""Build x86_64 Linux and Windows BOMBKI executables with FPC in TP mode.

Run on either Linux or Windows with FPC installed and available as ``fpc``
(or selected with ``--fpc`` / ``FPC``). The non-host target also needs its FPC
RTL units and cross-binutils. Use ``--run`` to launch the host-native result.
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
}
DEFAULT_CROSS_PREFIX = {
    "linux": "x86_64-linux-",
    "windows": "x86_64-w64-mingw32-",
}


def find_program(directory: Path, target: str) -> Path:
    names = ("BOMBKI.exe", "BOMBKI") if target == "windows" else ("BOMBKI", "BOMBKI.exe")
    for name in names:
        candidate = directory / name
        if candidate.is_file() and candidate.stat().st_size:
            return candidate
    raise FileNotFoundError(f"FPC did not produce a nonempty BOMBKI executable in {directory}")


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
                        help="target to build; repeat for both (default: linux and windows)")
    parser.add_argument("--linux-cross-prefix",
                        help="binutils prefix for a non-native Linux target (or FPC_LINUX_CROSS_PREFIX)")
    parser.add_argument("--windows-cross-prefix",
                        help="binutils prefix for a non-native Windows target (or FPC_WINDOWS_CROSS_PREFIX)")
    parser.add_argument("--output-dir", type=Path,
                        default=PROJECT / "build" / "fpc",
                        help="directory for both executables (default: build/fpc)")
    parser.add_argument("--run", action="store_true",
                        help="run the host-native executable after building both targets")
    args = parser.parse_args()

    try:
        host = host_target()
        targets = args.targets or [host, *(target for target in TARGET_FLAGS if target != host)]
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
                print(f"Building {target} x86_64...")
                for name in (*UNIT_NAMES, PROGRAM_NAME):
                    source = SOURCES / f"{name}.PAS"
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
                            f"FPC failed building {target} x86_64. {detail}"
                        ) from error

                binary = find_program(build_dir, target)
                suffix = ".exe" if target == "windows" else ""
                destination = output_dir / f"BOMBKI-{target}-x86_64{suffix}"
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
