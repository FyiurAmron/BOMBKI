#!/usr/bin/env python3
"""Rewrite _reconstructed/BOMBKI.PAS into the loadable Android game library.

The desktop targets compile the reconstructed program as it stands. Android
cannot: the APK ships the game as ``lib/arm64-v8a/libbombki.so``, which the
forked pty child opens with ``dlopen`` and drives through an exported
``BombkiMain``, so the main block has to become a procedure the library
exports.

Rather than carry ``{$IFDEF ANDROID}`` blocks in the reconstructed source, this
script writes that transformation out as a copy which only the ``android``
build of ``tools/build_fpc.py`` compiles. Four anchors move - the program
header, the main block's label declaration (it has to sit next to the body
using it once that body is a procedure), the main block's ``begin`` and the
closing ``end.`` - and each is located and checked before anything is
written, so a source edit that invalidates them fails loudly instead of
yielding a half-patched file.

    tools/android/make_library.py _reconstructed/BOMBKI.PAS -o build/BOMBKI.PAS

With no ``--output`` the rewritten source goes to stdout.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


PROGRAM_NAME = "BOMBKI"
ENTRY_POINT = "BombkiMain"

PROGRAM = re.compile(rf"program\s+{PROGRAM_NAME}\s*;", re.IGNORECASE)
LABEL = "label"
LIBRARY = f"library {PROGRAM_NAME};"
PROCEDURE = f"procedure {ENTRY_POINT};"

BANNER = [
    "{ Written by tools/android/make_library.py from _reconstructed/BOMBKI.PAS",
    "  for the Android build only; the desktop targets compile the",
    "  reconstructed source unchanged. Do not edit this copy - it is",
    "  regenerated on every build.",
    "  Android runs the game as a shared library: the APK ships this file",
    "  as lib/arm64-v8a/libbombki.so, and the forked child in",
    "  tools/android/native/pty.c loads it with dlopen and calls",
    f"  {ENTRY_POINT} once the pty is wired onto fds 0/1/2. Only the main",
    "  block is wrapped below, and only in this copy. }",
]

FOOTER = [
    "end;",
    "",
    f"exports {ENTRY_POINT};",
    "",
    "begin",
    "  { Library main block: deliberately empty. Android starts the game",
    f"    by calling {ENTRY_POINT}() from the forked pty child. }}",
    "end.",
]


class PatchError(RuntimeError):
    """The source no longer has the shape this script rewrites."""


def read_lines(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        raise PatchError(f"cannot read {path}: {error}") from error
    # No newline handling: the reconstructed sources are LF-terminated ASCII and
    # a stray CR would only make the anchors below harder to see.
    return text.splitlines()


def program_header(lines: list[str]) -> int:
    """Index of the ``program BOMBKI;`` line that opens the source."""
    for index, line in enumerate(lines):
        if PROGRAM.fullmatch(line.strip()):
            return index
    raise PatchError("no `program BOMBKI;` header line found; already patched?")


def label_declaration(lines: list[str]) -> tuple[int, int]:
    """Bounds of the top-level label declaration, including its semicolon."""
    start = next((index for index, line in enumerate(lines)
                  if line.strip() == LABEL), None)
    if start is None:
        raise PatchError("no top-level `label` declaration found")
    for stop in range(start, len(lines)):
        if lines[stop].rstrip().endswith(";"):
            return start, stop + 1
    raise PatchError(f"unterminated `label` declaration at line {start + 1}")


def main_block(lines: list[str]) -> int:
    """Index of the ``begin`` that opens the program's main block.

    Procedure bodies are indented, so an unindented ``begin`` can only be a
    main block, and the program's is the last one in the file.
    """
    for index in range(len(lines) - 1, -1, -1):
        if lines[index] == "begin":
            return index
    raise PatchError("no main block `begin` found")


def program_end(lines: list[str]) -> int:
    """Index of the closing ``end.``, ignoring trailing blank lines."""
    end = len(lines) - 1
    while end >= 0 and not lines[end].strip():
        end -= 1
    if end < 0:
        raise PatchError("the source is empty")
    if lines[end].strip() != "end.":
        raise PatchError(f"the source does not end with `end.` (line {end + 1})")
    return end


def patch(lines: list[str]) -> list[str]:
    header = program_header(lines)
    labels_start, labels_stop = label_declaration(lines)
    main = main_block(lines)
    end = program_end(lines)
    if not header < labels_start <= labels_stop <= main < end:
        raise PatchError("program header, labels, main block and `end.` are out of "
                         "the expected order; adjust this script rather than the "
                         "rewrite it just produced")
    return [
        *lines[:header],
        LIBRARY,
        *BANNER,
        *lines[header + 1:labels_start],
        *lines[labels_stop:main],
        PROCEDURE,
        *lines[labels_start:labels_stop],
        *lines[main:end],
        *FOOTER,
        *lines[end + 1:],
    ]


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="the reconstructed BOMBKI.PAS")
    parser.add_argument("-o", "--output", type=Path,
                        help="file to write (default: stdout)")
    args = parser.parse_args()

    try:
        source = args.source.expanduser()
        lines = read_lines(source)
        rewritten = patch(lines)
        if args.output is None:
            sys.stdout.write("\n".join(rewritten) + "\n")
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text("\n".join(rewritten) + "\n", encoding="utf-8")
    except (PatchError, OSError) as error:
        print(f"make_library.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())