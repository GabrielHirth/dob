#!/usr/bin/env sh
# build-arm.sh — produce dob-<ver>-arm64.img (RPi 4/5 / UTM) via mkimg.
# REQUIRES FreeBSD host (arm64 build). Run as root.
#
# Usage: ./build-arm.sh [--resume]
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
DOB_TARGET=arm64

NCPU=$(sysctl -n hw.ncpu)
STAGE=/tmp/dob-arm64-root

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

# 1. Ensure src/ports at pinned release
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

# 2. Build world + kernel for arm64
if $RESUME && step_done build; then
    echo "=== Build step already complete, skipping (--resume) ==="
else
    echo "=== DOB build: starting buildworld for arm64 ==="
    cd /usr/src
    # Skip in-tree LLVM build via dob-src.conf; use host toolchain.
    run_and_stream /tmp/dob-arm-build.log \
        make -j"${NCPU}" buildworld buildkernel \
            KERNCONF=GENERIC TARGET=arm64 TARGET_ARCH=aarch64 \
            SRCCONF="${DOB_ROOT}/build/dob-src.conf" \
            XCC=/usr/bin/cc XCXX=/usr/bin/c++ XCPP=/usr/bin/cpp XLD=/usr/bin/ld
    echo "make exit code: ${RC}"
    tail -50 /tmp/dob-arm-build.log
    if [ "${RC}" -ne 0 ]; then
        echo "ERROR: buildworld failed (exit ${RC}). Re-run with --resume to retry from this step." >&2
        exit "${RC}"
    fi
    mark_done build
fi

# 3. Install to staging root
# 4. Extract packages (base.txz, kernel.txz, packages.txz) if present in release output
# 5. Apply DOB overlay
# 6. Install DOB packages into staging root
if $RESUME && step_done stage; then
    echo "=== Stage step already complete, skipping (--resume) ==="
else
    rm -rf "${STAGE}"
    mkdir -p "${STAGE}"
    make -j"${NCPU}" installworld installkernel distribution \
        KERNCONF=GENERIC TARGET=arm64 TARGET_ARCH=aarch64 DESTDIR="${STAGE}" \
        SRCCONF="${DOB_ROOT}/build/dob-src.conf" \
        XCC=/usr/bin/cc XCXX=/usr/bin/c++ XCPP=/usr/bin/cpp XLD=/usr/bin/ld

    OBJ_DIR="/usr/obj/usr/src/arm64.aarch64/release"
    for txz in base.txz kernel.txz packages.txz; do
        if [ -f "${OBJ_DIR}/${txz}" ]; then
            tar -xf "${OBJ_DIR}/${txz}" -C "${STAGE}"
        fi
    done

    cp -r "${DOB_OVERLAY}/"* "${STAGE}/"

    if command -v pkg >/dev/null 2>&1; then
        pkg -r "${STAGE}" install -y $(grep -v '^#' "${DOB_PKGLIST}" | tr '\n' ' ')
    fi
    mark_done stage
fi

# 7. Rasterize boot splash + wallpaper on build host
if $RESUME && step_done assets; then
    echo "=== Asset step already complete, skipping (--resume) ==="
else
    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w 1920 -h 1080 "${DOB_OVERLAY}/usr/local/share/dob/art/boot-splash.svg" \
            -o "${STAGE}/usr/local/share/dob/splash/boot-splash-1920x1080.png"
        rsvg-convert -w 1366 -h 768  "${DOB_OVERLAY}/usr/local/share/dob/art/boot-splash.svg" \
            -o "${STAGE}/usr/local/share/dob/splash/boot-splash-1366x768.png"
        rsvg-convert -w 1920 -h 1080 "${DOB_OVERLAY}/usr/local/share/dob/art/wallpaper.svg" \
            -o "${STAGE}/usr/local/share/dob/theme/wallpaper/mountain.png"
    fi
    mark_done assets
fi

# 8. Build EFI partition image
# 9. Build root UFS image
# 10. Assemble final disk image (GPT: EFI + UFS)
# 11. For RPi: prepend U-Boot (optional; requires sysutils/u-boot-rpi-arm64)
# 12. SHA256SUMS
if $RESUME && step_done assemble; then
    echo "=== Assemble step already complete, skipping (--resume) ==="
else
    EFI_IMG=/tmp/dob-arm64-efi.img
    rm -f "${EFI_IMG}"
    makefs -t msdos "${EFI_IMG}" "${STAGE}/boot/efi" 2>/dev/null || \
        mkimg -s mbr -p efi:=${STAGE}/boot/efi -o "${EFI_IMG}"

    ROOT_IMG=/tmp/dob-arm64-root.img
    rm -f "${ROOT_IMG}"
    makefs "${ROOT_IMG}" "${STAGE}"

    IMG="dob-${DOB_VERSION}-arm64.img"
    rm -f "${IMG}"
    mkimg -s gpt \
        -p efi:=${EFI_IMG} \
        -p freebsd-ufs:=${ROOT_IMG} \
        -o "${IMG}"

    UBOOT=/usr/local/share/u-boot/rpi_arm64/u-boot.img
    if [ -f "${UBOOT}" ]; then
        dd if="${UBOOT}" of="${IMG}" conv=notrunc bs=512 seek=64
    fi

    sha256 "${IMG}" > SHA256SUMS
    mark_done assemble
fi

echo "Build complete: dob-${DOB_VERSION}-arm64.img + SHA256SUMS"
