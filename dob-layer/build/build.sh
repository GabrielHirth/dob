#!/usr/bin/env sh
# build.sh — produce dob-<ver>-amd64.iso (hybrid UEFI+BIOS live/install).
# REQUIRES a FreeBSD build host (bare metal or UTM VM). Run as root.
set -eu

. "$(dirname "$0")/pins.sh"

# Resolve DOB overlay and pkg list relative to this script's directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOB_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DOB_OVERLAY="${DOB_ROOT}/overlay"
DOB_PKGLIST="${DOB_ROOT}/pkg-list/dob-manifest.pkglist"

# 1. Ensure FreeBSD src/ports at pinned release exist
if [ ! -d /usr/src ]; then
    git clone --branch "releng/${DOB_FREEBSD_REL}" https://git.FreeBSD.org/src.git /usr/src
fi
if [ ! -d /usr/ports ]; then
    git clone --branch "releng/${DOB_FREEBSD_REL}" https://git.FreeBSD.org/ports.git /usr/ports
fi

# 2. Build x86_64 ISO via release.sh with DOB config
cd /usr/src/release
env DOB_OVERLAY="${DOB_OVERLAY}" \
    DOB_PKGLIST="${DOB_PKGLIST}" \
    DOB_VERSION="${DOB_VERSION}" \
    sh release.sh -c "${DOB_ROOT}/build/DOB-release.conf" amd64

# 3. Rasterize boot splash PNGs from SVG on the build host (rsvg-convert from graphics/librsvg2)
if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1920 -h 1080 "${DOB_OVERLAY}/usr/local/share/dob/art/boot-splash.svg" \
        -o "${DOB_OVERLAY}/usr/local/share/dob/splash/boot-splash-1920x1080.png"
    rsvg-convert -w 1366 -h 768  "${DOB_OVERLAY}/usr/local/share/dob/art/boot-splash.svg" \
        -o "${DOB_OVERLAY}/usr/local/share/dob/splash/boot-splash-1366x768.png"
    # Also rasterize wallpaper
    rsvg-convert -w 1920 -h 1080 "${DOB_OVERLAY}/usr/local/share/dob/art/wallpaper.svg" \
        -o "${DOB_OVERLAY}/usr/local/share/dob/theme/wallpaper/mountain.png"
    # Rasterize desktop splash source SVG if needed (optional)
    echo "Splash and wallpaper PNGs rasterized from SVG sources."
else
    echo "WARNING: rsvg-convert not found; using placeholder PNGs. Install graphics/librsvg2 for production images."
fi

# 4. Run retint.sh for icon theme (applies red-gloss to Breeze icons)
if [ -f "${DOB_OVERLAY}/usr/local/share/dob/icons/retint.sh" ]; then
    sh "${DOB_OVERLAY}/usr/local/share/dob/icons/retint.sh" \
        "${DOB_OVERLAY}/usr/local/share/dob/icons/DOB-Red/apps" \
        "${DOB_OVERLAY}/usr/local/share/dob/icons/DOB-Red/apps" \
        "#C0102A"
fi

# 5. Apply DOB theme defaults (LookAndFeel, ColorScheme, Icons, Kvantum)
if [ -f "${DOB_OVERLAY}/usr/local/share/dob/theme/apply.sh" ]; then
    sh "${DOB_OVERLAY}/usr/local/share/dob/theme/apply.sh"
fi

# 6. Copy built ISO to working directory
ISO_SRC="/usr/obj/usr/src/amd64.amd64/release/iso/dob-${DOB_VERSION}-amd64.iso"
ISO_DST="dob-${DOB_VERSION}-amd64.iso"
cp "${ISO_SRC}" "${ISO_DST}"

# 7. Generate SHA256SUMS
sha256 "${ISO_DST}" > SHA256SUMS

echo "Build complete: ${ISO_DST} + SHA256SUMS"