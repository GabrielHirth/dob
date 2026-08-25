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
echo "=== DOB build: checking /usr/src ==="
if [ ! -d /usr/src ] || ! (cd /usr/src && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    echo "Re-cloning FreeBSD src (branch: releng/${DOB_FREEBSD_REL})..."
    # Unmount if busy (e.g., from previous build)
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
echo "=== DOB build: checking for buildworld target ==="
grep -n '^buildworld:' /usr/src/Makefile 2>/dev/null || echo "ERROR: buildworld target not in Makefile"

# 2. Build x86_64 ISO via release.sh with DOB config
echo "=== DOB build: running release.sh ==="
cd /usr/src/release
# Use dob-src.conf to skip in-tree LLVM build; host toolchain via XCC/XCXX
env DOB_OVERLAY="${DOB_OVERLAY}" \
    DOB_PKGLIST="${DOB_PKGLIST}" \
    DOB_VERSION="${DOB_VERSION}" \
    SRCCONF="${DOB_ROOT}/build/dob-src.conf" \
    XCC=/usr/bin/cc \
    XCXX=/usr/bin/c++ \
    XCPP=/usr/bin/cpp \
    XLD=/usr/bin/ld \
    sh release.sh -c "${DOB_ROOT}/build/DOB-release.conf" amd64 2>&1 | tee /tmp/dob-release.log
echo "release.sh exit code: ${PIPESTATUS[0]}"
tail -50 /tmp/dob-release.log

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