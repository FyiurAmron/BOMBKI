#!/usr/bin/env bash
# Install the aarch64 Android FPC RTL units and NDK cross tools, configure a
# target-aware FPC wrapper, and verify it with a minimal Android smoke test.
#
# The RTL units come from the official FPC aarch64-android distribution, so they
# always match the host compiler version. Inside the wrapper,
# `tools/build_fpc.py --target android --fpc fpc-android` builds BOMBKI for
# Android arm64 with no further setup.

set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_ROOT="$PROJECT/build/tmp"
FPC_NAME="${FPC:-fpc}"
INSTALL_DIR=""
INSTALL_DIR_SET=0
PATH_DIR="${HOME}/.local/bin"
API_LEVEL=""
ARCHIVE=""
INSTALL_PACKAGES=1
DOWNLOAD_ARCHIVE=""
NDK_ROOT=""
NDK_VERSION="r26d"
TEMP_DIR=""

CROSS_PREFIX="aarch64-linux-android21-"

usage() {
  cat <<'EOF'
Usage: setup_fpc_android_cross.sh [options]

Install/configure aarch64 Android cross-compilation on Debian/Ubuntu x86_64
Linux, so that the host FPC can emit Android arm64 binaries. Installs only
missing binutils packages, downloads the FPC aarch64-android RTL units when they
are absent, and exposes a versioned fpc-android command under the configured path
directory (default: ~/.local/bin). A minimal Pascal program is compiled for
Android arm64 as a smoke test. If the toolchain is already complete, it reports
that and exits without testing.

Options:
  --fpc PATH           FPC executable (default: FPC env var or fpc)
  --install-dir PATH   Private RTL/wrapper/tool directory
  --path-dir PATH      Directory for the fpc-android command (default: ~/.local/bin)
  --ndk-root PATH      Android NDK root (default: ANDROID_NDK_ROOT/NDK_ROOT env var)
  --ndk-version VER    NDK version to download when none is found (default: r26d)
  --api-level N        Android API level for the NDK sysroot libraries
                       (default: highest one found in the NDK)
  --archive PATH       Use an already downloaded matching FPC Android archive
  --skip-packages      Do not run apt; use already installed binutils packages
  -h, --help           Show this help
EOF
}

fail() {
  printf 'setup_fpc_android_cross.sh: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --fpc) (($# >= 2)) || fail '--fpc requires a path'; FPC_NAME="$2"; shift 2 ;;
    --install-dir) (($# >= 2)) || fail '--install-dir requires a path'; INSTALL_DIR="$2"; INSTALL_DIR_SET=1; shift 2 ;;
    --path-dir) (($# >= 2)) || fail '--path-dir requires a path'; PATH_DIR="$2"; shift 2 ;;
    --ndk-root) (($# >= 2)) || fail '--ndk-root requires a path'; NDK_ROOT="$2"; shift 2 ;;
    --ndk-version) (($# >= 2)) || fail '--ndk-version requires a value'; NDK_VERSION="$2"; shift 2 ;;
    --api-level) (($# >= 2)) || fail '--api-level requires a value'; API_LEVEL="$2"; shift 2 ;;
    --archive) (($# >= 2)) || fail '--archive requires a path'; ARCHIVE="$2"; shift 2 ;;
    --skip-packages) INSTALL_PACKAGES=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == Linux ]] || fail 'this setup helper supports Linux hosts only'
[[ "$(uname -m)" == x86_64 ]] || fail 'this setup helper supports x86_64 hosts only'
command -v tar >/dev/null 2>&1 || fail 'tar is required'

FPC_PATH="$(command -v "$FPC_NAME" || true)"
[[ -n "$FPC_PATH" ]] || fail "FPC not found: $FPC_NAME"
FPC_VERSION="$("$FPC_PATH" -iV 2>/dev/null | head -n 1)"
[[ "$FPC_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "cannot determine FPC version from $FPC_PATH"
[[ "$("$FPC_PATH" -iTP 2>/dev/null)" == x86_64 ]] || fail 'FPC must target x86_64'
[[ "$("$FPC_PATH" -iTO 2>/dev/null)" == linux ]] || fail 'the installed FPC must be a Linux compiler'
if ((!INSTALL_DIR_SET)); then
  INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fpc-cross/$FPC_VERSION-android"
fi
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
PATH_DIR="$(mkdir -p "$PATH_DIR" && cd "$PATH_DIR" && pwd)"
UNITS_ROOT="$INSTALL_DIR/units/aarch64-android"
RTL_DEST="$UNITS_ROOT/rtl"
CONSOLE_DEST="$UNITS_ROOT/rtl-console"
WRAPPER="$INSTALL_DIR/fpc-wrapper"
PATH_COMMAND="$PATH_DIR/fpc-android"
BIN_DIR="$INSTALL_DIR/bin"
ARCHIVE_URL="https://downloads.freepascal.org/fpc/dist/$FPC_VERSION/aarch64-android/fpc-$FPC_VERSION.aarch64-android.tar"

find_ndk_root() {
  local candidate
  for candidate in "$NDK_ROOT" "${ANDROID_NDK_ROOT:-}" "${ANDROID_NDK_HOME:-}" "${NDK_ROOT:-}"; do
    [[ -n "$candidate" && -d "$candidate" ]] || continue
    candidate="$(cd "$candidate" && pwd)"
    [[ -d "$candidate/toolchains/llvm/prebuilt" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  for candidate in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" /opt/android-sdk /usr/lib/android-sdk; do
    [[ -n "$candidate" && -d "$candidate/ndk" ]] || continue
    local newest
    newest="$(ls -1 "$candidate/ndk" 2>/dev/null | sort -V | tail -n 1)"
    [[ -n "$newest" ]] || continue
    candidate="$(cd "$candidate/ndk/$newest" && pwd)"
    [[ -d "$candidate/toolchains/llvm/prebuilt" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

download_ndk() {
  local url="https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux.zip"
  local archive="$TEMP_ROOT/android-ndk-$NDK_VERSION-linux.zip"
  local destination="${NDK_ROOT:-$INSTALL_DIR}"
  command -v curl >/dev/null 2>&1 || fail 'curl is required to download the Android NDK'
  command -v unzip >/dev/null 2>&1 || fail 'unzip is required to unpack the Android NDK'
  # Progress goes to stderr: the function's stdout is captured as the path.
  printf 'Downloading the Android NDK %s from %s\n' "$NDK_VERSION" "$url" >&2
  mkdir -p "$TEMP_ROOT" "$destination"

  # The archive is several hundred megabytes and dl.google.com drops HTTP/2
  # streams on long transfers, so retry and resume, forcing HTTP/1.1 where
  # available. Verify the size afterwards rather than trusting curl's exit.
  local expected actual
  expected="$(curl -fsIL "$url" | tr -d '\r' | awk 'tolower($1) == "content-length:" {v = $2} END {print v}')"
  local attempt
  for attempt in 1 2 3 4 5; do
    # --http1.1 because the HTTP/2 streams on this host get reset mid-transfer.
    curl -fL -C - --http1.1 --retry 5 --retry-delay 3 --retry-all-errors \
      -o "$archive" "$url" || true
    actual="$(stat -c%s "$archive" 2>/dev/null || echo 0)"
    if [[ -n "$expected" && "$actual" == "$expected" ]]; then
      break
    fi
    printf 'NDK download attempt %s incomplete (%s of %s bytes), retrying\n' \
      "$attempt" "$actual" "${expected:-unknown}" >&2
    sleep 3
  done

  unzip -q -t "$archive" >/dev/null 2>&1 || fail "could not download the Android NDK: $url"
  unzip -q -o "$archive" -d "$destination" || fail 'could not unpack the Android NDK archive'
  printf '%s\n' "$destination/android-ndk-$NDK_VERSION"
}

llvm_bin_dir() {
  local prebuilt="$1/toolchains/llvm/prebuilt"
  local host
  for host in linux-x86_64 darwin-x86_64; do
    [[ -d "$prebuilt/$host/bin" ]] && { printf '%s\n' "$prebuilt/$host/bin"; return 0; }
  done
  printf '%s\n' "$prebuilt/$(ls -1 "$prebuilt" 2>/dev/null | head -n 1)/bin"
}

sysroot_lib_dir() {
  local root="$1"
  local libroot="$root/toolchains/llvm/prebuilt"
  local host api
  for host in linux-x86_64 darwin-x86_64; do
    [[ -d "$libroot/$host" ]] || continue
    for api in $(ls -1 "$libroot/$host/sysroot/usr/lib/aarch64-linux-android" 2>/dev/null | sort -n); do
      [[ -f "$libroot/$host/sysroot/usr/lib/aarch64-linux-android/$api/crtbegin_dynamic.o" ]] || continue
      printf '%s\n' "$libroot/$host/sysroot/usr/lib/aarch64-linux-android/$api"
      return 0
    done
  done
  return 1
}

rtl_installed() {
  [[ -s "$RTL_DEST/system.ppu" && -s "$CONSOLE_DEST/crt.ppu" ]]
}

# FPC ships one code generator binary per target CPU ("ppc<cpu>"); Debian's FPC
# package only installs the host's, and the official Android distribution carries
# an Android-built one, so the host ppca64 has to be built from FPC source. It is
# a single compiler build and bootstraps with the host compiler in seconds.
ppca64_available() {
  command -v ppca64 >/dev/null 2>&1 && return 0
  [[ -x "$BIN_DIR/ppca64" ]] && return 0
  local lib_dir
  lib_dir="$(dirname "$FPC_PATH")/../lib/x86_64-linux-gnu/fpc/$FPC_VERSION"
  [[ -x "$lib_dir/ppca64" ]] && return 0
  return 1
}

build_ppca64() {
  local version_url="https://downloads.freepascal.org/fpc/dist/$FPC_VERSION/source/fpc-$FPC_VERSION.source.tar.gz"
  command -v make >/dev/null 2>&1 || fail 'make is required to build the aarch64 code generator'
  command -v tar >/dev/null 2>&1 || fail 'tar is required to build the aarch64 code generator'
  [[ -n "$TEMP_DIR" ]] || TEMP_DIR="$(mktemp -d "$TEMP_ROOT/fpc-android-smoke.XXXXXX")"
  mkdir -p "$TEMP_ROOT"
  local archive="$TEMP_ROOT/fpc-$FPC_VERSION.source.tar.gz"
  if ! tar -tzf "$archive" >/dev/null 2>&1; then
    printf 'Downloading FPC %s sources to build ppca64 from %s\n' "$FPC_VERSION" "$version_url"
    curl -fL -C - --http1.1 --retry 5 --retry-delay 3 --retry-all-errors \
      -o "$archive" "$version_url" || fail "could not download the FPC sources: $version_url"
    tar -tzf "$archive" >/dev/null 2>&1 \
      || fail "the downloaded FPC sources are not a usable archive: $archive"
  fi
  printf 'Building ppca64 (aarch64 code generator) for this host...\n'
  tar -xzf "$archive" -C "$TEMP_DIR" "fpc-$FPC_VERSION/compiler" \
    || fail 'could not unpack the FPC compiler sources'
  (
    cd "$TEMP_DIR/fpc-$FPC_VERSION/compiler" || exit 1
    make AARCH64=1 ppca64
  ) >"$TEMP_DIR/ppca64-build.log" 2>&1 \
    || { tail -n 20 "$TEMP_DIR/ppca64-build.log" >&2; fail 'building ppca64 failed'; }
  [[ -x "$TEMP_DIR/fpc-$FPC_VERSION/compiler/ppca64" ]] || fail 'ppca64 was not built'
  cp -f "$TEMP_DIR/fpc-$FPC_VERSION/compiler/ppca64" "$BIN_DIR/ppca64"
  printf 'Installed ppca64 in %s\n' "$BIN_DIR"
}

if ! NDK_DIR="$(find_ndk_root)"; then
  mkdir -p "$TEMP_ROOT"
  NDK_DIR="$(download_ndk)"
fi
[[ -d "$NDK_DIR/toolchains/llvm/prebuilt" ]] || fail "Android NDK not usable: $NDK_DIR"
NDK_DIR="$(cd "$NDK_DIR" && pwd)"
LLVM_BIN="$(llvm_bin_dir "$NDK_DIR")"
[[ -d "$LLVM_BIN" ]] || fail "Android NDK has no LLVM toolchain: $NDK_DIR"
if [[ -z "$API_LEVEL" ]]; then
  SYSROOT_LIB="$(sysroot_lib_dir "$NDK_DIR")" || fail 'no Android API level sysroot libraries found in the NDK'
  API_LEVEL="$(basename "$SYSROOT_LIB")"
else
  SYSROOT_LIB="$(sysroot_lib_dir "$NDK_DIR")"
  [[ "$(basename "$SYSROOT_LIB")" == "$API_LEVEL" ]] \
    || SYSROOT_LIB="$(dirname "$SYSROOT_LIB")/$API_LEVEL"
  [[ -f "$SYSROOT_LIB/crtbegin_dynamic.o" ]] \
    || fail "Android API level $API_LEVEL sysroot libraries not found: $SYSROOT_LIB"
fi

link_tools() {
  local tool="$1" target="$2"
  if [[ -n "$LLVM_BIN/$target" && -x "$LLVM_BIN/$target" ]]; then
    ln -sfn "$LLVM_BIN/$target" "$BIN_DIR/$CROSS_PREFIX$tool"
    return 0
  fi
  local host_tool
  host_tool="$(command -v "$target" || true)"
  [[ -n "$host_tool" ]] && ln -sfn "$host_tool" "$BIN_DIR/$CROSS_PREFIX$tool" && return 0
  return 1
}

# FPC drives the assembler like GNU as, while llvm-as defaults to emitting
# assembly, so wrap it to always produce an object file.
install_assembler() {
  local script="$BIN_DIR/${CROSS_PREFIX}as"
  # Drop any earlier symlink first: writing through it would clobber the NDK
  # tool the link points at.
  rm -f "$script"
  local host_as
  host_as="$(command -v aarch64-linux-gnu-as || true)"
  if [[ -n "$host_as" ]]; then
    ln -sfn "$host_as" "$script"
    return 0
  fi
  # NDK clang can assemble, but only when told which target to emit for.
  if [[ -x "$LLVM_BIN/clang" ]]; then
    {
      printf '#!/usr/bin/env bash\n'
      printf 'exec %q --target=aarch64-linux-android%s -c -x assembler "$@"\n' \
        "$LLVM_BIN/clang" "$API_LEVEL"
    } > "$script"
    chmod 755 "$script"
    return 0
  fi
  return 1
}

MISSING_PACKAGES=()
# binutils are not optional: FPC generates a linker script that uses INSERT,
# which only GNU ld implements (its own sources note lld/gold cannot handle it).
if ! command -v aarch64-linux-gnu-ld >/dev/null 2>&1; then
  MISSING_PACKAGES=(binutils-aarch64-linux-gnu)
fi
if ((${#MISSING_PACKAGES[@]})); then
  if ((!INSTALL_PACKAGES)); then
    fail "binutils packages missing: ${MISSING_PACKAGES[*]} (--skip-packages prevents installing them)"
  fi
  command -v apt-get >/dev/null 2>&1 || fail 'apt-get is required (Debian/Ubuntu)'
  if ((EUID == 0)); then
    APT=(apt-get)
  elif command -v sudo >/dev/null 2>&1; then
    APT=(sudo apt-get)
  else
    fail 'install binutils as root, or rerun where sudo is available; alternatively use --skip-packages'
  fi
  printf 'Installing missing packages: %s\n' "${MISSING_PACKAGES[*]}"
  "${APT[@]}" update
  "${APT[@]}" install -y "${MISSING_PACKAGES[@]}"
fi

mkdir -p "$BIN_DIR"
install_assembler || fail 'no aarch64 assembler found (aarch64-linux-gnu-as or NDK clang)'
# GNU ld is mandatory: FPC's Android link script uses INSERT, which lld rejects
# with "unable to insert .data after .data1".
GNULD="$(command -v aarch64-linux-gnu-ld || true)"
[[ -n "$GNULD" ]] || fail 'GNU aarch64 ld not found; install binutils-aarch64-linux-gnu'
ln -sfn "$GNULD" "$BIN_DIR/${CROSS_PREFIX}ld"
link_tools ar llvm-ar || true
link_tools nm llvm-nm || true
link_tools strip llvm-strip || true
link_tools objcopy llvm-objcopy || true
link_tools ranlib llvm-ranlib || true
link_tools readelf llvm-readelf || true

if ! ppca64_available; then
  build_ppca64
else
  printf 'aarch64 code generator (ppca64) already available; skipping build.\n'
fi

if ! rtl_installed; then
  mkdir -p "$TEMP_ROOT"
  [[ -n "$TEMP_DIR" ]] || TEMP_DIR="$(mktemp -d "$TEMP_ROOT/fpc-android-smoke.XXXXXX")"
  if [[ -z "$ARCHIVE" ]]; then
    command -v curl >/dev/null 2>&1 || fail 'curl is required to download the FPC aarch64-android archive'
    ARCHIVE="$TEMP_ROOT/fpc-$FPC_VERSION.aarch64-android.tar"
    DOWNLOAD_ARCHIVE="$ARCHIVE"
    printf 'Downloading FPC %s aarch64-android units from %s\n' "$FPC_VERSION" "$ARCHIVE_URL"
    curl -fL -C - --http1.1 --retry 5 --retry-delay 3 --retry-all-errors \
      -o "$ARCHIVE" "$ARCHIVE_URL" \
      || fail "could not download the FPC aarch64-android archive: $ARCHIVE_URL"
  else
    ARCHIVE="$(cd "$(dirname "$ARCHIVE")" && pwd)/$(basename "$ARCHIVE")"
    [[ -s "$ARCHIVE" ]] || fail "archive not found or empty: $ARCHIVE"
  fi

  OUTER="fpc-$FPC_VERSION.aarch64-android"
  BASE_TAR="aarch64-android-base.x86_64-linux.tar.gz"
  CONSOLE_TAR="units-rtl-console.aarch64-android.tar.gz"
  tar -tf "$ARCHIVE" "$OUTER/binary.aarch64-android.tar" >/dev/null 2>&1 \
    || fail "archive is not the official FPC $FPC_VERSION aarch64-android distribution"

  mkdir -p "$RTL_DEST" "$CONSOLE_DEST"
  printf 'Extracting aarch64-android RTL units...\n'
  tar -xOf "$ARCHIVE" "$OUTER/binary.aarch64-android.tar" \
    | tar -xOf - "$BASE_TAR" \
    | tar -xzf - -C "$RTL_DEST" --strip-components=3 --wildcards 'units/aarch64-android/rtl/*'
  tar -xOf "$ARCHIVE" "$OUTER/binary.aarch64-android.tar" \
    | tar -xOf - "$CONSOLE_TAR" \
    | tar -xzf - -C "$CONSOLE_DEST" --strip-components=6 --wildcards \
        'lib/fpc/*/units/aarch64-android/rtl-console/*'
  rtl_installed || fail 'the FPC aarch64-android archive did not contain the RTL system and crt units'
else
  printf 'FPC %s aarch64-android RTL units already installed; skipping download.\n' "$FPC_VERSION"
fi

{
  printf '#!/usr/bin/env bash\n'
  printf 'FPC_EXEC=%q\n' "$FPC_PATH"
  printf 'TOOL_DIR=%q\n' "$BIN_DIR"
  printf 'RTL_DIR=%q\n' "$RTL_DEST"
  printf 'CONSOLE_DIR=%q\n' "$CONSOLE_DEST"
  printf 'SYSROOT_LIB=%q\n' "$SYSROOT_LIB"
  printf 'CROSS_PREFIX=%q\n' "$CROSS_PREFIX"
  cat <<'EOF'
# FPC looks up the per-CPU code generator (ppca64) on PATH.
case ":$PATH:" in
  *":$TOOL_DIR:"*) ;;
  *) PATH="$TOOL_DIR:$PATH" ;;
esac
export PATH
case " $* " in
  *" -Tandroid "*|*" -Taarch64-android "*)
    exec "$FPC_EXEC" "$@" \
      "-Fu$RTL_DIR" "-Fu$CONSOLE_DIR" \
      "-Fl$SYSROOT_LIB" \
      "-XP$CROSS_PREFIX"
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
printf 'Android RTL units: %s\n' "$UNITS_ROOT"
printf 'Android NDK: %s\n' "$NDK_DIR"
printf 'Android API level: %s\n' "$API_LEVEL"
printf 'Cross-binutils prefix: %s/\n' "$BIN_DIR"
printf 'FPC wrapper: %s\n' "$PATH_COMMAND"
case ":$PATH:" in
  *":$PATH_DIR:"*) ;;
  *) printf 'Add this to your shell configuration to use it by command name:\n  export PATH=%q:"$PATH"\n' "$PATH_DIR" ;;
esac

[[ -n "$TEMP_DIR" ]] || TEMP_DIR="$(mktemp -d "$TEMP_ROOT/fpc-android-smoke.XXXXXX")"
mkdir -p "$TEMP_DIR/out" "$TEMP_DIR/units"
cat > "$TEMP_DIR/FpcAndroidSmoke.pas" <<'EOF'
program FpcAndroidSmoke;
begin
end.
EOF
PATH="$BIN_DIR:$PATH" "$PATH_COMMAND" -B -Mtp -Tandroid -Paarch64 \
  -FU"$TEMP_DIR/units" -FE"$TEMP_DIR/out" "$TEMP_DIR/FpcAndroidSmoke.pas"
[[ -s "$TEMP_DIR/out/FpcAndroidSmoke" ]] \
  || fail 'the Android arm64 smoke test did not produce an executable'
file "$TEMP_DIR/out/FpcAndroidSmoke" | grep -q "ARM aarch64" \
  || fail 'the smoke test did not produce an ARM aarch64 executable'
printf 'Android arm64 Pascal smoke test passed.\n'