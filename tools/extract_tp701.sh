#!/bin/sh
#
# Extract the TP7.01 compiler/runtime files needed by build_tp7_dosbox.py.
#
# Usage:
#   tools/extract_tp701.sh [installation-data] [output-root]
#
# The supplied installation data is a directory named tp701.all.  The
# output root has the DOS installation layout expected by the build helper:
#   <output-root>/BIN/TPC.EXE
#   <output-root>/BIN/TURBO.TPL
#
# TPC.EXE comes from Disk10/TPC.ZIP.  TURBO.TPL comes from Disk8/RTPL.ZIP;
# the latter is the TP7.01 runtime library whose LONG.OBJ matches the
# original BOMBKI runtime.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
ARCHIVE_DIR=${1:-"$SCRIPT_DIR/tp701.all"}
OUTPUT_DIR=${2:-"$PROJECT_DIR/build/tp701"}

case "${1:-}" in
  -h|--help)
    sed -n '2,13p' "$0"
    exit 0
    ;;
esac

if ! command -v unzip >/dev/null 2>&1; then
  echo "error: unzip is required" >&2
  exit 2
fi
if ! command -v sha256sum >/dev/null 2>&1; then
  echo "error: sha256sum is required" >&2
  exit 2
fi

if [ ! -d "$ARCHIVE_DIR" ]; then
  echo "error: TP7.01 installation data not found: $ARCHIVE_DIR" >&2
  exit 2
fi

TPC_ZIP="$ARCHIVE_DIR/Disk10/TPC.ZIP"
TPL_ZIP="$ARCHIVE_DIR/Disk8/RTPL.ZIP"
if [ ! -f "$TPC_ZIP" ] || [ ! -f "$TPL_ZIP" ]; then
  echo "error: TP7.01 payload ZIPs are missing under $ARCHIVE_DIR" >&2
  echo "expected: Disk10/TPC.ZIP and Disk8/RTPL.ZIP" >&2
  exit 2
fi

TMP_ROOT="$PROJECT_DIR/build/tmp"
mkdir -p "$TMP_ROOT"
TMP_DIR=$(mktemp -d "$TMP_ROOT/tp701.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

unzip -t "$TPC_ZIP" >/dev/null
unzip -t "$TPL_ZIP" >/dev/null
unzip -p "$TPC_ZIP" TPC.EXE >"$TMP_DIR/TPC.EXE"
unzip -p "$TPL_ZIP" TURBO.TPL >"$TMP_DIR/TURBO.TPL"

check_file() {
  file=$1
  expected_size=$2
  expected_hash=$3
  actual_size=$(wc -c <"$file")
  actual_hash=$(sha256sum "$file" | awk '{print $1}')
  if [ "$actual_size" -ne "$expected_size" ] || [ "$actual_hash" != "$expected_hash" ]; then
    echo "error: extracted payload verification failed: $file" >&2
    echo "expected: $expected_size bytes, $expected_hash" >&2
    echo "actual:   $actual_size bytes, $actual_hash" >&2
    exit 1
  fi
}

check_file "$TMP_DIR/TPC.EXE" 75432 \
  72211facc2159c758fd6db2a6076517568d82654f1a6b92539745af50274e3f0
check_file "$TMP_DIR/TURBO.TPL" 48464 \
  025cf348b34b737f7db84e98b77041d25c7d62e6210e2c410e660f5149c05896

mkdir -p "$OUTPUT_DIR/BIN"
cp "$TMP_DIR/TPC.EXE" "$OUTPUT_DIR/BIN/TPC.EXE"
cp "$TMP_DIR/TURBO.TPL" "$OUTPUT_DIR/BIN/TURBO.TPL"

echo "Extracted TP7.01 compiler/runtime to $OUTPUT_DIR"
echo "  $OUTPUT_DIR/BIN/TPC.EXE"
echo "  $OUTPUT_DIR/BIN/TURBO.TPL"
