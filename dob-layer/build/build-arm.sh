#!/usr/bin/env bash
# build-arm.sh — produce dob-<ver>-arm64.img (RPi/UTM) via mkimg.
# REQUIRES FreeBSD host. Documents ARM device-tree needs.
set -euo pipefail
source "$(dirname "$0")/pins.sh"

# ARM64 layout (RPi/UTM) via mkimg:
#   1. EFI system partition (FAT32) for UEFI boot
#   2. FreeBSD UFS root filesystem with DOB overlay + pkg set
#   3. Optional: U-Boot / RPi firmware for bare-metal RPi boot

# Steps (on FreeBSD host):
# 1. Build FreeBSD world/kernel for arm64 (aarch64)
#    cd /usr/src
#    make -j$(sysctl -n hw.ncpu) buildworld buildkernel KERNCONF=GENERIC TARGET=arm64 TARGET_ARCH=aarch64

# 2. Create root filesystem with packages
#    mkdir -p /tmp/dob-arm64-root
#    # Extract base.txz, kernel.txz, packages.txz to /tmp/dob-arm64-root
#    # Apply DOB overlay: cp -r "${DOB_OVERLAY}"/* /tmp/dob-arm64-root/
#    # Install packages from DOB_PKGLIST into /tmp/dob-arm64-root (pkg -r /tmp/dob-arm64-root install -y ...)

# 3. Create EFI partition image
#    mkimg -s gpt \
#      -p efi:=/tmp/efi.img \
#      -p freebsd-ufs:=/tmp/dob-arm64-root.img \
#      -o dob-${DOB_VERSION}-arm64.img

# 4. For RPi: prepend U-Boot / firmware (dd if=/usr/local/share/u-boot/rpi_arm64/u-boot.img of=dob-${DOB_VERSION}-arm64.img conv=notrunc)

# 5. sha256sum -> SHA256SUMS
#    sha256 dob-${DOB_VERSION}-arm64.img > SHA256SUMS

IMG="dob-${DOB_VERSION}-arm64.img"
echo "Would build $IMG on FreeBSD host (mkimg + DOB overlay)."
echo "Outputs: $IMG + SHA256SUMS"