#!/usr/bin/env python3
"""Compare TP7-rebuilt artifacts with the originals in _reference/.

The reconstruction claim is byte-for-byte equality: compiling
_reconstructed/*.PAS with the genuine TP7.01 compiler must produce the
same TPU units and the same EXE as the 1999 release. This tool is the
verdict for the tp7-conformance workflow; it is also handy locally,
against build/tp7 after `tools/build_tp7_dosbox.py --no-run`.

Every artifact is compared byte for byte. A difference is a failure, and
the report points at where it starts: file offset, expected and actual
bytes, and how far the sizes diverge. TP7 writes no self-describing
headers into a TPU beyond a fixed 44-byte header, so a report of raw
offsets is the honest thing to hand over - the interesting question
("which of my procedures moved?") needs the TP7 unit format, and until
something actually differs, guessing at it here would only be noise.

    tools/compare_tp7_artifacts.py --candidate-dir build/tp7
    tools/compare_tp7_artifacts.py --candidate-dir build/tp7 --quiet
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_REFERENCE = PROJECT / "_reference"

# The units the program is linked from, then the program itself. BOMBKI.MAP
# is deliberately absent: the linker map is not part of the release, it
# exists to be read when something else differs.
ARTIFACTS = ("MONSTRA.TPU", "PRZEDM.TPU", "SWIAT.TPU", "BOMBKI.EXE")
# Bytes shown per artifact before the output is summarised.
DETAIL_LIMIT = 16


class CompareError(RuntimeError):
    """The comparison could not be set up or carried out."""


def compare(expected: bytes, actual: bytes) -> tuple[list[tuple[int, int, int]], int]:
    """Return the differing in-range byte positions and the size delta."""
    differences = [(offset, want, got)
                   for offset, (want, got) in enumerate(zip(expected, actual))
                   if want != got]
    return differences, abs(len(expected) - len(actual))


def report(name: str, expected: bytes, actual: bytes, quiet: bool) -> bool:
    """Print the verdict for one artifact; return True when it matches."""
    differences, size_delta = compare(expected, actual)
    total = len(differences) + size_delta
    if not total:
        print(f"PASS {name}: byte-identical ({len(actual)} bytes)")
        return True

    first_offset, first_expected, first_actual = (
        differences[0] if differences else (min(len(expected), len(actual)), 0, 0))
    print(f"FAIL {name}: {total} differing byte position(s); "
          f"reference={len(expected)} bytes, rebuilt={len(actual)} bytes; "
          f"first at 0x{first_offset:04X}, "
          f"reference=0x{first_expected:02X}, rebuilt=0x{first_actual:02X}")
    if quiet:
        return False
    for offset, want, got in differences[:DETAIL_LIMIT]:
        print(f"  offset 0x{offset:04X}: reference=0x{want:02X}, rebuilt=0x{got:02X}")
    if len(differences) > DETAIL_LIMIT:
        print(f"  ... {len(differences) - DETAIL_LIMIT} more in-range differences")
    if size_delta:
        common = min(len(expected), len(actual))
        print(f"  length-only difference begins at offset 0x{common:04X}")
    return False


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--candidate-dir", type=Path,
                        help="directory with the rebuilt artifacts "
                             "(default: build/tp7)")
    parser.add_argument("--reference-dir", type=Path, default=DEFAULT_REFERENCE,
                        help=f"directory with the originals (default: {DEFAULT_REFERENCE.name}/)")
    parser.add_argument("--artifact", action="append", dest="artifacts",
                        help="compare only this artifact; repeatable "
                             f"(default: {', '.join(ARTIFACTS)})")
    parser.add_argument("--quiet", action="store_true",
                        help="one line per artifact, no offset detail")
    args = parser.parse_args()

    try:
        candidate_dir = (args.candidate_dir or PROJECT / "build" / "tp7").expanduser()
        reference_dir = args.reference_dir.expanduser()
        failures = 0
        compared = 0
        for name in args.artifacts or ARTIFACTS:
            reference = reference_dir / name
            candidate = candidate_dir / name
            if not reference.is_file():
                raise CompareError(f"original missing: {reference}")
            if not candidate.is_file():
                raise CompareError(f"rebuilt artifact missing: {candidate}")
            compared += 1
            if not report(name, reference.read_bytes(), candidate.read_bytes(), args.quiet):
                failures += 1

        if failures:
            print(f"\n{failures} of {compared} rebuilt artifact(s) differ from "
                  f"{reference_dir.name}/; the reconstruction is not byte-exact")
            return 1
        print(f"\nAll {compared} rebuilt artifacts are byte-identical to "
              f"{reference_dir.name}/")
        return 0
    except (CompareError, OSError) as error:
        print(f"compare_tp7_artifacts.py: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())