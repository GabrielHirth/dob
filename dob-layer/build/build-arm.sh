#!/usr/bin/env sh
# build-arm.sh — produce dob-<ver>-arm64.img (RPi 4/5 / UTM) via mkimg.
# REQUIRES FreeBSD host (arm64 build). Run as root.
set -eu

. "$(dirname "$0")/pins.sh"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOB_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DOB_OVERLAY="${DOB_ROOT}/overlay"
DOB_PKGLIST="${DOB_ROOT}/pkg-list/dob-manifest.pkglist"

NCPU=$(sysctl -n hw.ncpu)

# 1. Ensure src/ports at pinned release
echo "=== DOB build: checking /usr/src ==="
if [ ! -d /usr/src ]; then
    echo "Cloning FreeBSD src (branch: releng/${DOB_FREEBSD_REL})..."
    git clone --branch "releng/${DOB_FREEBSD_REL}" https://git.FreeBSD.org/src.git /usr/src
else
    echo "/usr/src exists. Current branch:"
    (cd /usr/src && git branch --show-current)
    echo "Last commit:"
    (cd /usr/src && git log -1 --oneline)
fi
echo "=== DOB build: checking /usr/ports ==="
if [ ! -d /usr/ports ]; then
    echo "Cloning FreeBSD ports (branch: main)..."
    git clone --branch main https://git.FreeBSD.org/ports.git /usr/ports
else
    echo "/usr/ports exists. Current branch:"
    (cd /usr/ports && git branch --show-current)
fi

echo "=== DOB build: verifying Makefile in /usr/src ==="
ls -la /usr/src/Makefile 2>/dev/null || echo "ERROR: /usr/src/Makefile NOT FOUND"
grep -n '^buildworld:' /usr/src/Makefile 2>/dev/null || echo "ERROR: buildworld target not in Makefile"

# 2. Build world + kernel for arm64
echo "=== DOB build: starting buildworld for arm64 ==="
cd /usr/src
make -j"${NCPU}" buildworld buildkernel KERNCONF=GENERIC TARGET=arm64 TARGET_ARCH=aarch64 2>&1 | tee /tmp/dob-arm-build.log
echo "make exit code: ${PIPESTATUS[0]}"
tail -50 /tmp/dob-arm-build.log

# 3. Install to staging root
STAGE=/tmp/dob-arm64-root
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
make -j"${NCPU}" installworld installkernel distribution \
    KERNCONF=GENERIC TARGET=arm64 TARGET_ARCH=aarch64 DESTDIR="${STAGE}"

# 4. Extract packages (base.txz, kernel.txz, packages.txz) if present in release output
OBJ_DIR="/usr/obj/usr/src/arm64.aarch64/release"
for txz in base.txz kernel.txz packages.txz; do
    if [ -f "${OBJ_DIR}/${txz}" ]; then
        tar -xf "${OBJ_DIR}/${txz}" -C "${STAGE}"
    fi
done

# 5. Apply DOB overlay
cp -r "${DOB_OVERLAY}/"* "${STAGE}/"

# 6. Install DOB packages into staging root
if command -v pkg >/dev/null 2>&1; then
    pkg -r "${STAGE}" install -y $(grep -v '^#' "${DOB_PKGLIST}" | tr '\n' ' ')
fi

# 7. Rasterize boot splash + wallpaper on build host
if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1920 -h 1080 "${DOB_OVERLAY}/usr/local/share/dob/art/boot-splash.svg" \
        -o "${STAGE}/usr/local/share/dob/splash/boot-splash-1920x1080.png"
    rsvg-convert -w 1366 -h 768  "${DOB_OVERLAY}/usr/local/share/dob/art/boot-splash.svg" \
        -o "${STAGE}/usr/local/share/dob/splash/boot-splash-1366x768.png"
    rsvg-convert -w 1920 -h 1080 "${DOB_OVERLAY}/usr/local/share/dob/art/wallpaper.svg" \
        -o "${STAGE}/usr/local/share/dob/theme/wallpaper/mountain.png"
fi

# 8. Build EFI partition image
EFI_IMG=/tmp/dob-arm64-efi.img
rm -f "${EFI_IMG}"
makefs -t msdos "${EFI_IMG}" "${STAGE}/boot/efi" 2>/dev/null || \
    mkimg -s mbr -p efi:=${STAGE}/boot/efi -o "${EFI_IMG}"

# 9. Build root UFS image
ROOT_IMG=/tmp/dob-arm64-root.img
rm -f "${ROOT_IMG}"
makefs "${ROOT_IMG}" "${STAGE}"

# 10. Assemble final disk image (GPT: EFI + UFS)
IMG="dob-${DOB_VERSION}-arm64.img"
rm -f "${IMG}"
mkimg -s gpt \
    -p efi:=${EFI_IMG} \
    -p freebsd-ufs:=${ROOT_IMG} \
    -o "${IMG}"

# 11. For RPi: prepend U-Boot (optional; requires sysutils/u-boot-rpi-arm64)
UBOOT=/usr/local/share/u-boot/rpi_arm64/u-boot.img
if [ -f "${UBOOT}" ]; then
    dd if="${UBOOT}" of="${IMG}" conv=notrunc bs=512 seek=64
fi

# 12. SHA256SUMS
sha256 "${IMG}" > SHA256SUMS

echo "Build complete: ${IMG} + SHA256SUMS"