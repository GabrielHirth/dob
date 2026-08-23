#!/usr/bin/env bash
# apply.sh — set DOB as the default theme for live + installed systems.
#
# NOTE ON WALLPAPER: the high-res mountain wallpaper is rasterized on the build
# host (rsvg-convert / rsvg-convert). On systems without an SVG rasterizer only a
# committed placeholder PNG ships; the build host replaces it with the real
# 1920x1080 raster of art/wallpaper.svg. The placeholder is a valid PNG so layout
# always succeeds.
set -euo pipefail

SHARE=/usr/local/share/dob/theme

# System-wide Plasma default drop-in (read by plasma at first run)
mkdir -p /usr/local/etc/xdg
cat > /usr/local/etc/xdg/kdeglobals <<EOF
[KDE]
LookAndFeelPackage=DOB
[General]
ColorScheme=DOB-Red
[Icons]
Theme=DOB-Red
EOF

# Kvantum default
mkdir -p /usr/local/etc/xdg/Kvantum
echo "kvantumTheme=DOB-Red" > /usr/local/etc/xdg/Kvantum/kvantum.kvconfig

echo "DOB theme applied (LookAndFeel=DOB, ColorScheme=DOB-Red, Icons=DOB-Red, Kvantum=DOB-Red)"
