#!/usr/bin/env python3
"""Build reconstructed units with genuine TP7 in DOSBox-X, then run BOMBKI.

Requires DOSBox-X and a TP7 installation. Set ``TP7_ROOT`` or pass
``--tp7-root`` if TP7 is not in a standard local path. The default is an
interactive DOSBox-X run; pass ``--no-run`` to build only.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
SOURCES = PROJECT / "_reconstructed"
TEMP_ROOT = PROJECT / "build" / "tmp"
ARTIFACTS = ("MONSTRA.TPU", "PRZEDM.TPU", "SWIAT.TPU", "BOMBKI.EXE", "BOMBKI.MAP")
SOURCE_TIMES = {
    "MONSTRA.PAS": (1999, 5, 27, 18, 44, 22),
    "SWIAT.PAS": (1999, 6, 12, 12, 56, 34),
    "PRZEDM.PAS": (1999, 6, 1, 19, 29, 32),
}


def find_tpc(explicit_root: Path | None) -> tuple[Path, Path]:
    """Find the TP7 installation and TPC.EXE in local standard locations."""
    candidates: list[Path] = []
    if explicit_root:
        candidates.append(explicit_root)
    if os.environ.get("TP7_ROOT"):
        candidates.append(Path(os.environ["TP7_ROOT"]))
    candidates.extend((
        PROJECT / "build" / "tmp" / "tp7",
        Path("/opt/tp7"),
        Path("/tools/tp7"),
    ))
    seen: set[Path] = set()
    for candidate in candidates:
        candidate = candidate.expanduser().resolve()
        if candidate in seen:
            continue
        seen.add(candidate)
        if candidate.is_file() and candidate.name.lower() == "tpc.exe":
            return candidate.parent.parent, candidate
        if not candidate.is_dir():
            continue
        direct = candidate / "BIN" / "TPC.EXE"
        if direct.is_file():
            return candidate, direct
        for executable in candidate.rglob("tpc.exe"):
            return candidate, executable
    searched = ", ".join(str(path) for path in candidates) or "(none)"
    raise FileNotFoundError(
        f"TPC.EXE not found; set TP7_ROOT or pass --tp7-root. Checked: {searched}"
    )


def dos_host_path(path: Path) -> str:
    value = path.resolve().as_posix()
    if '"' in value:
        raise ValueError(f'DOSBox-X host path cannot contain a double quote: {value}')
    return f'"{value}"'


def build_config(tp7_root: Path, tpc: Path, build_dir: Path) -> str:
    compiler_relative = tpc.relative_to(tp7_root).as_posix().replace("/", "\\")
    compiler_dos = f"c:\\{compiler_relative}"
    commands = [
        f'{compiler_dos} /GD monstra.pas > d:\\tp7-build.log',
        f'{compiler_dos} /GD przedm.pas >> d:\\tp7-build.log',
        f'{compiler_dos} /GD swiat.pas >> d:\\tp7-build.log',
        f'{compiler_dos} /GD bombki.pas >> d:\\tp7-build.log',
    ]
    lines = [
        "[dosbox]", "machine=svga_bridge", "memsize=32", "",
        "[cpu]", "core=auto", "cputype=pentium", "",
        "[render]", "frameskip=0", "",
        "[sdl]", "fullscreen=false", "fulldouble=false", "autolock=false", "",
        "[mixer]", "nosound=true", "",
        "[dos]", "ver=7.0", "",
        "[autoexec]",
        f"mount c {dos_host_path(tp7_root)}",
        f"mount d {dos_host_path(build_dir)}",
        "d:", *commands, "exit", "",
    ]
    return "\n".join(lines)


def run_config(dosbox: str, config: Path, *, headless: bool = False) -> None:
    environment = os.environ.copy()
    if headless and sys.platform != "win32":
        environment["SDL_VIDEODRIVER"] = "dummy"
        environment["SDL_AUDIODRIVER"] = "dummy"
    subprocess.run([dosbox, "-conf", str(config)], check=True, env=environment)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tp7-root", type=Path,
                        help="TP7 installation root (default: TP7_ROOT or known local paths)")
    parser.add_argument("--dosbox-x", default=os.environ.get("DOSBOX_X", "dosbox-x"),
                        help="DOSBox-X executable (default: DOSBOX_X env var or dosbox-x)")
    parser.add_argument("--output-dir", type=Path,
                        default=PROJECT / "build" / "tp7",
                        help="directory for generated TPU/EXE artifacts (default: build/tp7)")
    parser.add_argument("--no-run", action="store_true",
                        help="compile only; do not launch BOMBKI.EXE")
    args = parser.parse_args()

    try:
        dosbox = shutil.which(args.dosbox_x)
        if not dosbox:
            raise FileNotFoundError(f"DOSBox-X executable not found: {args.dosbox_x}")
        tp7_root, tpc = find_tpc(args.tp7_root)
        output_dir = args.output_dir.expanduser().resolve()
        output_dir.mkdir(parents=True, exist_ok=True)
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        print(f"TPC: {tpc}")
        print(f"TP7 root: {tp7_root}")

        with tempfile.TemporaryDirectory(prefix="bombki-tp7-", dir=TEMP_ROOT) as temporary:
            build_dir = Path(temporary).resolve()
            for source_name in ("MONSTRA.PAS", "PRZEDM.PAS", "SWIAT.PAS", "BOMBKI.PAS"):
                source = SOURCES / source_name
                target = build_dir / source_name
                text = source.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
                target.write_bytes(text.replace(b"\n", b"\r\n"))
                if source_name in SOURCE_TIMES:
                    timestamp = datetime(*SOURCE_TIMES[source_name]).timestamp()
                    os.utime(target, (timestamp, timestamp))

            config = build_dir / "tp7-build.conf"
            config.write_text(build_config(tp7_root, tpc, build_dir), encoding="utf-8")
            run_config(dosbox, config, headless=True)

            log = build_dir / "tp7-build.log"
            if not log.is_file():
                raise RuntimeError("DOSBox-X produced no TP7 build log")
            log_text = log.read_bytes().decode("cp437", "replace")
            banners = len(re.findall(r"Turbo Pascal.*Version 7", log_text, re.IGNORECASE))
            if banners < 4:
                raise RuntimeError(f"expected four genuine TP7 compiler banners; found {banners}\n{log_text}")
            if re.search(r"(?:Error\s+\d+:|Fatal:)", log_text, re.IGNORECASE):
                raise RuntimeError(f"TP7 reported a compile error:\n{log_text}")

            for name in ARTIFACTS:
                artifact = build_dir / name
                if not artifact.is_file() or artifact.stat().st_size == 0:
                    raise RuntimeError(f"TP7 did not produce a nonempty {name}\n{log_text}")
                shutil.copy2(artifact, output_dir / name)
            shutil.copy2(log, output_dir / log.name)
            print(f"Built TP7 artifacts in {output_dir}")

            if not args.no_run:
                run_config_path = build_dir / "tp7-run.conf"
                run_config_path.write_text("\n".join((
                    "[dosbox]", "machine=svga_bridge", "memsize=32", "",
                    "[cpu]", "core=auto", "cputype=pentium", "",
                    "[render]", "frameskip=0", "",
                    "[sdl]", "fullscreen=false", "fulldouble=false", "autolock=false", "",
                    "[mixer]", "nosound=true", "",
                    "[dos]", "ver=7.0", "",
                    "[autoexec]", f"mount d {dos_host_path(output_dir)}", "d:",
                    "BOMBKI.EXE", "exit", "",
                )), encoding="utf-8")
                print("Launching BOMBKI.EXE in DOSBox-X. Exit the game or close DOSBox-X to return.")
                run_config(dosbox, run_config_path)
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        print(f"build_tp7_dosbox.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
