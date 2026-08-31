#!/usr/bin/env sh
# build.sh — produce dob-<ver>-amd64.iso (hybrid UEFI+BIOS live/install).
# REQUIRES a FreeBSD build host (bare metal or UTM VM). Run as root.
#
# Usage: ./build.sh [--resume]
#   --resume  skip steps that already completed (based on sentinel files)
set -eu

. "$(dirname "$0")/pins.sh"

# --- Argument parsing -------------------------------------------------------
RESUME=false
for arg in "$@"; do
    case "$arg" in
        --resume) RESUME=true ;;
        -h|--help)
            echo "Usage: $0 [--resume]"
            echo "  --resume  skip already-completed steps"
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

# --- Resolve paths ---------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOB_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DOB_OVERLAY="${DOB_ROOT}/overlay"
DOB_PKGLIST="${DOB_ROOT}/pkg-list/dob-manifest.pkglist"
DOB_TARGET=amd64

# --- Resume sentinel helpers -----------------------------------------------
sentinel_dir="/tmp/dob-resume-${DOB_TARGET}"
step_done()   { [ -f "${sentinel_dir}/$1" ]; }
mark_done()   { mkdir -p "$sentinel_dir" && touch "${sentinel_dir}/$1"; }

# --- Streaming log helper ---------------------------------------------------
# Runs CMD writing to LOG, streaming live to stdout via background tail.
# Sets RC to the command's exit code.
run_and_stream() {
    _log="$1"
    shift
    : > "${_log}"
    tail -f "${_log}" &
    _tail_pid=$!
    "$@" > "${_log}" 2>&1
    RC=$?
    kill "${_tail_pid}" 2>/dev/null || true
    wait "${_tail_pid}" 2>/dev/null || true
}

# 1. Ensure FreeBSD src/ports at pinned release exist
if $RESUME && step_done clone; then
    echo "=== Clone step already complete, skipping (--resume) ==="
else
    echo "=== DOB build: checking /usr/src ==="
    if [ ! -d /usr/src ] || ! (cd /usr/src && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        echo "Re-cloning FreeBSD src (branch: releng/${DOB_FREEBSD_REL})..."
        umount /usr/src 2>/dev/null || true
        rm -rf /usr/src
        git clone --branch "releng/${DOB_FREEBSD_REL}" https://git.FreeBSD.org/src.git /usr/src
        echo "Clone exit code: $?"
    else
        echo "/usr/src exists and is a git repo. Current branch:"
        (cd /usr/src && git branch --show-current)
        echo "Last commit:"
        (cd /usr/src && git log -1 --oneline)
    fi
    echo "=== DOB build: checking /usr/ports ==="
    if [ ! -d /usr/ports ] || ! (cd /usr/ports && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        echo "Re-cloning FreeBSD ports (branch: main)..."
        umount /usr/ports 2>/dev/null || true
        rm -rf /usr/ports
        git clone --branch main https://git.FreeBSD.org/ports.git /usr/ports
        echo "Clone exit code: $?"
    else
        echo "/usr/ports exists and is a git repo. Current branch:"
        (cd /usr/ports && git branch --show-current)
    fi
    echo "=== DOB build: verifying Makefile in /usr/src ==="
    ls -la /usr/src/Makefile 2>/dev/null || echo "ERROR: /usr/src/Makefile NOT FOUND"
    grep -n '^buildworld:' /usr/src/Makefile 2>/dev/null || echo "ERROR: buildworld target not in Makefile"
    mark_done clone
fi

# 2. Build x86_64 ISO via release.sh with DOB config
#    Use dob-src.conf to skip in-tree LLVM build; host toolchain via XCC/XCXX/XCPP/XLD.
if $RESUME && step_done build; then
    echo "=== Build step already complete, skipping (--resume) ==="
else
    echo "=== DOB build: running release.sh ==="
    cd /usr/src/release
    run_and_stream /tmp/dob-release.log \
        env DOB_OVERLAY="${DOB_OVERLAY}" \
            DOB_PKGLIST="${DOB_PKGLIST}" \
            DOB_VERSION="${DOB_VERSION}" \
            SRCCONF="${DOB_ROOT}/build/dob-src.conf" \
            XCC=/usr/bin/cc \
            XCXX=/usr/bin/c++ \
            XCPP=/usr/bin/cpp \
            XLD=/usr/bin/ld \
            sh release.sh -c "${DOB_ROOT}/build/DOB-release.conf" amd64
    echo "release.sh exit code: ${RC}"
    tail -50 /tmp/dob-release.log
    if [ "${RC}" -ne 0 ]; then
        echo "ERROR: release.sh failed (exit ${RC}). Re-run with --resume to retry from this step." >&2
        exit "${RC}"
    fi
    mark_done build
fi

# 3. Rasterize boot splash PNGs from SVG on the build host (rsvg-convert from graphics/librsvg2)
# 4. Run retint.sh for icon theme (applies red-gloss to Breeze icons)
# 5. Apply DOB theme defaults (LookAndFeel, ColorScheme, Icons, Kvantum)
if $RESUME && step_done assets; then
    echo "=== Asset step already complete, skipping (--resume) ==="
else
    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w 1920 -h 1080 "${DOB_OVERLAY}/usr/local/share/dob/art/boot-splash.svg" \
            -o "${DOB_OVERLAY}/usr/local/share/dob/splash/boot-splash-1920x1080.png"
        rsvg-convert -w 1366 -h 768  "${DOB_OVERLAY}/usr/local/share/dob/art/boot-splash.svg" \
            -o "${DOB_OVERLAY}/usr/local/share/dob/splash/boot-splash-1366x768.png"
        rsvg-convert -w 1920 -h 1080 "${DOB_OVERLAY}/usr/local/share/dob/art/wallpaper.svg" \
            -o "${DOB_OVERLAY}/usr/local/share/dob/theme/wallpaper/mountain.png"
        echo "Splash and wallpaper PNGs rasterized from SVG sources."
    else
        echo "WARNING: rsvg-convert not found; using placeholder PNGs. Install graphics/librsvg2 for production images."
    fi

    if [ -f "${DOB_OVERLAY}/usr/local/share/dob/icons/retint.sh" ]; then
        sh "${DOB_OVERLAY}/usr/local/share/dob/icons/retint.sh" \
            "${DOB_OVERLAY}/usr/local/share/dob/icons/DOB-Red/apps" \
            "${DOB_OVERLAY}/usr/local/share/dob/icons/DOB-Red/apps" \
            "#C0102A"
    fi

    if [ -f "${DOB_OVERLAY}/usr/local/share/dob/theme/apply.sh" ]; then
        sh "${DOB_OVERLAY}/usr/local/share/dob/theme/apply.sh"
    fi
    mark_done assets
fi

# 6. Copy built ISO to working directory
# 7. Generate SHA256SUMS
if $RESUME && step_done assemble; then
    echo "=== Assemble step already complete, skipping (--resume) ==="
else
    ISO_SRC="/usr/obj/usr/src/amd64.amd64/release/iso/dob-${DOB_VERSION}-amd64.iso"
    ISO_DST="dob-${DOB_VERSION}-amd64.iso"
    cp "${ISO_SRC}" "${ISO_DST}"
    sha256 "${ISO_DST}" > SHA256SUMS
    mark_done assemble
fi

echo "Build complete: dob-${DOB_VERSION}-amd64.iso + SHA256SUMS"
