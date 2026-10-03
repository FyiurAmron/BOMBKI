#!/usr/bin/env bash
# Install the Win64 FPC RTL and MinGW cross tools, configure a target-aware
# FPC wrapper, and verify it with a minimal Win64 Pascal smoke test.

set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_ROOT="$PROJECT/build/tmp"
FPC_NAME="${FPC:-fpc}"
INSTALL_DIR=""
INSTALL_DIR_SET=0
PATH_DIR="${HOME}/.local/bin"
MINGW_LIB_DIR="/usr/x86_64-w64-mingw32/lib"
ARCHIVE=""
INSTALL_PACKAGES=1
DOWNLOAD_ARCHIVE=""
TEMP_DIR=""

usage() {
  cat <<'EOF'
Usage: setup_fpc_windows_cross.sh [options]

Install/configure x86_64 Windows cross-compilation on Debian/Ubuntu x86_64
Linux. Installs only missing MinGW packages, downloads the Win64 RTL only
when its units are absent, and exposes a versioned fpc-win64 command under
the configured path directory (default: ~/.local/bin). A minimal Pascal
program is compiled for Win64 as a smoke test. If the toolchain is already
complete, it reports that and exits without testing.

Options:
  --fpc PATH             FPC executable (default: FPC env var or fpc)
  --install-dir PATH     Private RTL/wrapper/tool directory
  --path-dir PATH        Directory for the fpc-win64 command (default: ~/.local/bin)
  --mingw-lib-dir PATH   MinGW import-library directory
  --archive PATH         Use an already downloaded matching FPC Win64 archive
  --skip-packages        Do not run apt; use already installed MinGW packages
  -h, --help             Show this help
EOF
}

fail() {
  printf 'setup_fpc_windows_cross.sh: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --fpc) (($# >= 2)) || fail '--fpc requires a path'; FPC_NAME="$2"; shift 2 ;;
    --install-dir) (($# >= 2)) || fail '--install-dir requires a path'; INSTALL_DIR="$2"; INSTALL_DIR_SET=1; shift 2 ;;
    --path-dir) (($# >= 2)) || fail '--path-dir requires a path'; PATH_DIR="$2"; shift 2 ;;
    --mingw-lib-dir) (($# >= 2)) || fail '--mingw-lib-dir requires a path'; MINGW_LIB_DIR="$2"; shift 2 ;;
    --archive) (($# >= 2)) || fail '--archive requires a path'; ARCHIVE="$2"; shift 2 ;;
    --skip-packages) INSTALL_PACKAGES=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == Linux ]] || fail 'this setup helper supports Linux hosts only'
[[ "$(uname -m)" == x86_64 ]] || fail 'this setup helper supports x86_64 hosts only'
command -v apt-get >/dev/null 2>&1 || fail 'apt-get is required (Debian/Ubuntu)'
command -v tar >/dev/null 2>&1 || fail 'tar is required'

FPC_PATH="$(command -v "$FPC_NAME" || true)"
[[ -n "$FPC_PATH" ]] || fail "FPC not found: $FPC_NAME"
FPC_VERSION="$("$FPC_PATH" -iV 2>/dev/null | head -n 1)"
[[ "$FPC_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "cannot determine FPC version from $FPC_PATH"
[[ "$("$FPC_PATH" -iTP 2>/dev/null)" == x86_64 ]] || fail 'FPC must target x86_64'
[[ "$("$FPC_PATH" -iTO 2>/dev/null)" == linux ]] || fail 'the installed FPC must be a Linux compiler'
if ((!INSTALL_DIR_SET)); then
  INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fpc-cross/$FPC_VERSION"
fi
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
PATH_DIR="$(mkdir -p "$PATH_DIR" && cd "$PATH_DIR" && pwd)"
RTL_DEST="$INSTALL_DIR/units/x86_64-win64"
WRAPPER="$INSTALL_DIR/fpc-wrapper"
PATH_COMMAND="$PATH_DIR/fpc-win64"
AS_LINK="$INSTALL_DIR/bin/x86_64-w64-mingw32-as"
LD_LINK="$INSTALL_DIR/bin/x86_64-w64-mingw32-ld"
APT_PACKAGES=(binutils-mingw-w64-x86-64 mingw-w64-x86-64-dev)

rtl_installed() {
  [[ -s "$RTL_DEST/rtl/system.ppu" && -s "$RTL_DEST/rtl-console/crt.ppu" ]]
}

link_points_to() {
  [[ -L "$1" && "$(readlink -f "$1" 2>/dev/null || true)" == \
    "$(readlink -f "$2" 2>/dev/null || true)" ]]
}

wrapper_is_current() {
  [[ -x "$WRAPPER" ]] || return 1
  cmp -s "$WRAPPER" <(
    printf '#!/usr/bin/env bash\n'
    printf 'FPC_EXEC=%q\n' "$FPC_PATH"
    printf 'RTL_DIR=%q\n' "$RTL_DEST/rtl"
    printf 'CONSOLE_DIR=%q\n' "$RTL_DEST/rtl-console"
    printf 'MINGW_LIB_DIR=%q\n' "$MINGW_LIB_DIR"
    cat <<'EOF'
case " $* " in
  *" -Twin64 "*)
    exec "$FPC_EXEC" "$@" "-Fu$RTL_DIR" "-Fu$CONSOLE_DIR" "-Fl$MINGW_LIB_DIR"
    ;;
  *) exec "$FPC_EXEC" "$@" ;;
esac
EOF
  )
}

path_command_is_current() {
  [[ -L "$PATH_COMMAND" && "$(readlink -f "$PATH_COMMAND" 2>/dev/null || true)" == \
    "$(readlink -f "$WRAPPER" 2>/dev/null || true)" ]]
}

MISSING_PACKAGES=()
command -v dpkg-query >/dev/null 2>&1 || fail 'dpkg-query is required to check MinGW package status'
for package in "${APT_PACKAGES[@]}"; do
  status="$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)"
  [[ "$status" == 'install ok installed' ]] || MISSING_PACKAGES+=("$package")
done

[[ -d "$MINGW_LIB_DIR" ]] && MINGW_LIB_DIR="$(cd "$MINGW_LIB_DIR" && pwd)"
AS_PATH="$(command -v x86_64-w64-mingw32-as || true)"
LD_PATH="$(command -v x86_64-w64-mingw32-ld || command -v x86_64-w64-mingw32-ld.bfd || true)"

if ((${#MISSING_PACKAGES[@]} == 0)) && [[ -d "$MINGW_LIB_DIR" ]] && \
   [[ -n "$AS_PATH" && -n "$LD_PATH" ]] && rtl_installed && \
   link_points_to "$AS_LINK" "$AS_PATH" && link_points_to "$LD_LINK" "$LD_PATH" && \
   wrapper_is_current && path_command_is_current; then
  printf 'FPC %s Win64 cross-toolchain is already installed and configured.\n' "$FPC_VERSION"
  printf 'Win64 RTL: %s\n' "$RTL_DEST"
  printf 'MinGW libraries: %s\n' "$MINGW_LIB_DIR"
  printf 'FPC wrapper: %s\n' "$PATH_COMMAND"
  printf 'Skipping setup actions and smoke test.\n'
  case ":$PATH:" in
    *":$PATH_DIR:"*) ;;
    *) printf 'Add this to your shell configuration to use it by command name:\n  export PATH=%q:"$PATH"\n' "$PATH_DIR" ;;
  esac
  exit 0
fi

if ((${#MISSING_PACKAGES[@]})); then
  if ((!INSTALL_PACKAGES)); then
    fail "MinGW packages missing: ${MISSING_PACKAGES[*]} (--skip-packages prevents installing them)"
  fi
  if ((EUID == 0)); then
    APT=(apt-get)
  elif command -v sudo >/dev/null 2>&1; then
    APT=(sudo apt-get)
  else
    fail 'install MinGW packages as root, or rerun where sudo is available; alternatively use --skip-packages'
  fi
  printf 'Installing missing MinGW packages: %s\n' "${MISSING_PACKAGES[*]}"
  "${APT[@]}" update
  "${APT[@]}" install -y "${MISSING_PACKAGES[@]}"
else
  printf 'MinGW packages already installed; skipping apt.\n'
fi

[[ -d "$MINGW_LIB_DIR" ]] || fail "MinGW import-library directory not found: $MINGW_LIB_DIR"
MINGW_LIB_DIR="$(cd "$MINGW_LIB_DIR" && pwd)"
AS_PATH="$(command -v x86_64-w64-mingw32-as || true)"
LD_PATH="$(command -v x86_64-w64-mingw32-ld || command -v x86_64-w64-mingw32-ld.bfd || true)"
[[ -n "$AS_PATH" ]] || fail 'x86_64-w64-mingw32-as not found; install binutils-mingw-w64-x86-64'
[[ -n "$LD_PATH" ]] || fail 'x86_64-w64-mingw32-ld(.bfd) not found; install binutils-mingw-w64-x86-64'

mkdir -p "$TEMP_ROOT"
TEMP_DIR="$(mktemp -d "$TEMP_ROOT/fpc-cross-smoke.XXXXXX")"
cleanup() {
  [[ -z "$TEMP_DIR" ]] || rm -rf "$TEMP_DIR"
  [[ -z "$DOWNLOAD_ARCHIVE" ]] || rm -f "$DOWNLOAD_ARCHIVE"
}
trap cleanup EXIT

if ! rtl_installed; then
  if [[ -z "$ARCHIVE" ]]; then
    command -v curl >/dev/null 2>&1 || fail 'curl is required to download the FPC Win64 RTL archive'
    ARCHIVE="$(mktemp "$TEMP_ROOT/fpc-win64-${FPC_VERSION}.XXXXXX.tar")"
    DOWNLOAD_ARCHIVE="$ARCHIVE"
    URL="https://downloads.freepascal.org/fpc/dist/${FPC_VERSION}/x86_64-win64/fpc-${FPC_VERSION}.x86_64-win64.tar"
    printf 'Downloading FPC %s Win64 RTL from %s\n' "$FPC_VERSION" "$URL"
    curl -fL --retry 2 -o "$ARCHIVE" "$URL" || fail "could not download matching FPC archive: $URL"
  else
    ARCHIVE="$(cd "$(dirname "$ARCHIVE")" && pwd)/$(basename "$ARCHIVE")"
    [[ -s "$ARCHIVE" ]] || fail "archive not found or empty: $ARCHIVE"
  fi

  OUTER="fpc-${FPC_VERSION}.x86_64-win64"
  tar -tf "$ARCHIVE" "$OUTER/binary.x86_64-win64.tar" >/dev/null 2>&1 \
    || fail "archive is not the official FPC ${FPC_VERSION} x86_64-win64 distribution"

  mkdir -p "$TEMP_DIR/rtl" "$TEMP_DIR/console"
  tar -xOf "$ARCHIVE" "$OUTER/binary.x86_64-win64.tar" \
    | tar -xOf - x86_64-win64-base.x86_64-linux.tar.gz \
    | tar -xzf - -C "$TEMP_DIR/rtl" --wildcards 'units/x86_64-win64/rtl/*'
  tar -xOf "$ARCHIVE" "$OUTER/binary.x86_64-win64.tar" \
    | tar -xOf - units-rtl-console.x86_64-win64.tar.gz \
    | tar -xzf - -C "$TEMP_DIR/console" --strip-components=5 --wildcards \
        "lib/fpc/$FPC_VERSION/units/x86_64-win64/rtl-console/*"

  [[ -s "$TEMP_DIR/rtl/units/x86_64-win64/rtl/system.ppu" ]] \
    || fail 'the downloaded archive did not contain the Win64 RTL system unit'
  [[ -s "$TEMP_DIR/console/rtl-console/crt.ppu" ]] \
    || fail 'the downloaded archive did not contain the Win64 console CRT unit'
  mkdir -p "$RTL_DEST"
  cp -a "$TEMP_DIR/rtl/units/x86_64-win64/rtl" "$RTL_DEST/"
  cp -a "$TEMP_DIR/console/rtl-console" "$RTL_DEST/"
else
  printf 'FPC %s Win64 RTL units already installed; skipping download.\n' "$FPC_VERSION"
fi

mkdir -p "$INSTALL_DIR/bin"
ln -sfn "$AS_PATH" "$AS_LINK"
ln -sfn "$LD_PATH" "$LD_LINK"
if AR_PATH="$(command -v x86_64-w64-mingw32-ar || true)"; then
  ln -sfn "$AR_PATH" "$INSTALL_DIR/bin/x86_64-w64-mingw32-ar"
fi

{
  printf '#!/usr/bin/env bash\n'
  printf 'FPC_EXEC=%q\n' "$FPC_PATH"
  printf 'RTL_DIR=%q\n' "$RTL_DEST/rtl"
  printf 'CONSOLE_DIR=%q\n' "$RTL_DEST/rtl-console"
  printf 'MINGW_LIB_DIR=%q\n' "$MINGW_LIB_DIR"
  cat <<'EOF'
case " $* " in
  *" -Twin64 "*)
    exec "$FPC_EXEC" "$@" "-Fu$RTL_DIR" "-Fu$CONSOLE_DIR" "-Fl$MINGW_LIB_DIR"
    ;;
  *) exec "$FPC_EXEC" "$@" ;;
esac
EOF
} > "$WRAPPER"
chmod 755 "$WRAPPER"
if [[ -e "$PATH_COMMAND" && ! -L "$PATH_COMMAND" ]]; then
  fail "refusing to replace existing non-symlink command: $PATH_COMMAND"
fi
ln -sfn "$WRAPPER" "$PATH_COMMAND"

printf '\nFPC: %s (%s)\n' "$FPC_PATH" "$FPC_VERSION"
printf 'Win64 RTL: %s\n' "$RTL_DEST"
printf 'MinGW libraries: %s\n' "$MINGW_LIB_DIR"
printf 'Cross-binutils prefix: %s/bin/x86_64-w64-mingw32-\n' "$INSTALL_DIR"
printf 'FPC wrapper: %s\n' "$PATH_COMMAND"
case ":$PATH:" in
  *":$PATH_DIR:"*) ;;
  *) printf 'Add this to your shell configuration to use it by command name:\n  export PATH=%q:"$PATH"\n' "$PATH_DIR" ;;
esac

mkdir -p "$TEMP_DIR/out" "$TEMP_DIR/units"
cat > "$TEMP_DIR/FpcCrossSmoke.pas" <<'EOF'
program FpcCrossSmoke;
begin
end.
EOF
"$PATH_COMMAND" -B -Mtp -Twin64 -Px86_64 \
  -XP"$INSTALL_DIR/bin/x86_64-w64-mingw32-" \
  -FU"$TEMP_DIR/units" -FE"$TEMP_DIR/out" "$TEMP_DIR/FpcCrossSmoke.pas"
[[ -s "$TEMP_DIR/out/FpcCrossSmoke.exe" ]] || fail 'Win64 smoke test did not produce FpcCrossSmoke.exe'
printf 'Win64 Pascal smoke test passed.\n'
