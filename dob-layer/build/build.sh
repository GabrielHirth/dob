#!/usr/bin/env bash
# build.sh — produce dob-<ver>-amd64.iso (hybrid UEFI+BIOS live/install).
# REQUIRES a FreeBSD build host (bhyve/UTM VM on macOS). Not run on macOS.
set -euo pipefail
source "$(dirname "$0")/pins.sh"

# 1. checkout pinned FreeBSD src+ports (documented; uses git in build env)
#    On FreeBSD host:
#    git clone --branch "releng/${DOB_FREEBSD_REL}" --depth 1 https://git.FreeBSD.org/src.git /usr/src
#    git clone --branch "releng/${DOB_FREEBSD_REL}" --depth 1 https://git.FreeBSD.org/ports.git /usr/ports

# 2. run release.sh with DOB-release.conf, injecting DOB_OVERLAY + DOB_PKGLIST
#    On FreeBSD host (as root or with appropriate permissions):
#    cd /usr/src/release
#    env DOB_OVERLAY="${DOB_OVERLAY}" \
#        DOB_PKGLIST="${DOB_PKGLIST}" \
#        DOB_VERSION="${DOB_VERSION}" \
#        sh release.sh -c ../DOB-release.conf amd64

# 3. wrap ISO as hybrid UEFI+BIOS
#    On FreeBSD host:
#    # The release.sh with DOB_BOOT="uefi+bios" produces hybrid ISO at:
#    # /usr/obj/usr/src/amd64.amd64/release/iso/dob-${DOB_VERSION}-amd64.iso
#    cp /usr/obj/usr/src/amd64.amd64/release/iso/dob-${DOB_VERSION}-amd64.iso .

# 4. sha256sum -> SHA256SUMS
#    On FreeBSD host:
#    sha256 dob-${DOB_VERSION}-amd64.iso > SHA256SUMS

ISO="dob-${DOB_VERSION}-amd64.iso"
echo "Would build $ISO on FreeBSD host (release.sh + DOB-release.conf)."
echo "Outputs: $ISO + SHA256SUMS"