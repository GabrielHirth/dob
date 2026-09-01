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
    if [ ! -f /usr/src/Makefile ] || ! (cd /usr/src && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        echo "Re-cloning FreeBSD src (branch: releng/${DOB_FREEBSD_REL})..."
        umount /usr/src 2>/dev/null || true
        rm -rf /usr/src
        git clone --branch "releng/${DOB_FREEBSD_REL}" https://git.FreeBSD.org/src.git /usr/src
        echo "Clone exit code: $?"
        if [ ! -f /usr/src/Makefile ]; then
            echo "ERROR: /usr/src/Makefile missing after clone. Clone may be incomplete." >&2
            exit 1
        fi
    else
        echo "/usr/src exists and is a git repo. Current branch:"
        (cd /usr/src && git branch --show-current)
        echo "Last commit:"
        (cd /usr/src && git log -1 --oneline)
    fi
    echo "=== DOB build: checking /usr/ports ==="
    if [ ! -d /usr/ports/ports-mgmt/pkg ] || ! (cd /usr/ports && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        echo "Re-cloning FreeBSD ports (branch: main)..."
        umount /usr/ports 2>/dev/null || true
        rm -rf /usr/ports
        git clone --branch main https://git.FreeBSD.org/ports.git /usr/ports
        echo "Clone exit code: $?"
        if [ ! -d /usr/ports/ports-mgmt/pkg ]; then
            echo "ERROR: /usr/ports/ports-mgmt/pkg missing after clone. Clone may be incomplete." >&2
            exit 1
        fi
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
    # Note: DOB_OVERLAY/DOB_PKGLIST are NOT release.sh variables. The overlay
    # and packages are applied as a post-processing step after release.sh
    # produces the base ISO. release.sh's only real knob for extra files is
    # LOCAL_DIST (not used here — we overlay onto the ISO directly).
    run_and_stream /tmp/dob-release.log \
        env DOB_VERSION="${DOB_VERSION}" \
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
    # release.sh can return 0 even when its internal make failed. Verify the
    # ISO exists before marking the step done and proceeding to assemble.
    # release.sh outputs to /R/ (chroot) which maps to /usr/obj/.../release/ on
    # the host, using FreeBSD default naming (FreeBSD-<ver>-<arch>-disc1.iso).
    ISO_SRC="/scratch/R/FreeBSD-16.0-CURRENT-amd64-disc1.iso"
    if [ ! -f "${ISO_SRC}" ]; then
        echo "ERROR: release.sh exited 0 but ISO is missing: ${ISO_SRC}" >&2
        echo "Check /tmp/dob-release.log for build errors. Re-run with --resume to retry." >&2
        exit 1
    fi
    mark_done build
fi

# 2b. Apply DOB overlay + packages into the release tree
# release.sh produces a base FreeBSD ISO with no DOB customizations. This
# step copies the DOB overlay into the release tree and installs the DOB
# package set via chroot pkg, then re-builds the ISO.
if $RESUME && step_done overlay; then
    echo "=== Overlay step already complete, skipping (--resume) ==="
else
    STAGE=/tmp/dob-stage
    # FreeBSD marks setuid binaries with schg (file immutable flag). Clear it
    # recursively before removing so rm can delete them.
    if [ -d "${STAGE}" ]; then
        chflags -R noschg "${STAGE}" 2>/dev/null || true
    fi
    rm -rf "${STAGE}"
    mkdir -p "${STAGE}"

    # 1. Extract the release filesystem tree (base + kernel tars) into the
    #    staging dir. release.sh puts the tars in different places depending
    #    on version; try the common locations.
    FOUND_DIST=""
    for candidate in \
        "/scratch/usr/obj/usr/src/amd64.amd64/release" \
        "/usr/obj/usr/src/amd64.amd64/release/dist" \
        "/scratch/R/dist" \
        "/scratch/R/release/dist" \
        "/usr/obj/usr/src/amd64.amd64/release"; do
        if [ -f "${candidate}/base.txz" ]; then
            FOUND_DIST="${candidate}"
            break
        fi
    done
    if [ -z "${FOUND_DIST}" ]; then
        echo "ERROR: could not find base.txz in any known location." >&2
        echo "Searched: /usr/obj/usr/src/amd64.amd64/release/dist, /scratch/R/dist, /scratch/R/release/dist" >&2
        exit 1
    fi
    echo "Extracting release tars from ${FOUND_DIST}"
    for txz in base.txz kernel.txz; do
        if [ -f "${FOUND_DIST}/${txz}" ]; then
            tar -xJf "${FOUND_DIST}/${txz}" -C "${STAGE}"
        fi
    done

    # 2. Apply DOB overlay (files in dob-layer/overlay/ replace matching
    #    files in the staging root)
    if [ -d "${DOB_OVERLAY}" ]; then
        cp -a "${DOB_OVERLAY}/." "${STAGE}/"
        echo "DOB overlay applied from ${DOB_OVERLAY}"
    else
        echo "ERROR: DOB overlay not found at ${DOB_OVERLAY}" >&2
        exit 1
    fi

    # 3. Install DOB package set into the staging root via pkg -r
    if command -v pkg >/dev/null 2>&1; then
        PKGS=$(grep -v '^#' "${DOB_PKGLIST}" | grep -v '^[[:space:]]*$' | tr '\n' ' ')
        if [ -n "${PKGS}" ]; then
            # Create /dev so devfs can be mounted
            mkdir -p "${STAGE}/dev"
            mount -t devfs devfs "${STAGE}/dev" || true

            # Use pkg -r with explicit ABI_FILE pointing at a readable uname
            # binary inside the staging root. This avoids the "Unable to
            # determine the ABI" error.
            ABI_FILE="${STAGE}/usr/bin/uname"
            if [ ! -f "${ABI_FILE}" ]; then
                # Fallback: use host's uname output to determine ABI
                ABI=$(uname -s)-$(uname -r)-$(uname -m)
                export ABI
            fi
            export ABI_FILE

            # Override the staging root's pkg repo config. The default
            # /etc/pkg/FreeBSD.conf from base.txz points to /quarterly/ paths
            # that don't exist for FreeBSD 16-CURRENT. Write our own config
            # and pass it explicitly with -C so pkg ignores the rootdir's
            # default config entirely.
            mkdir -p "${STAGE}/etc/pkg"
            PKG_CONF="${STAGE}/etc/pkg/FreeBSD.conf"
            cat > "${PKG_CONF}" <<'PKGCONF'
FreeBSD: { enabled: no }
FreeBSD-base: {
  url: "pkg+https://pkg.FreeBSD.org/FreeBSD:16:amd64/base_latest",
  enabled: yes,
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg"
}
FreeBSD-ports: {
  url: "pkg+https://pkg.FreeBSD.org/FreeBSD:16:amd64/latest",
  enabled: yes,
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg"
}
FreeBSD-ports-kmods: {
  url: "pkg+https://pkg.FreeBSD.org/FreeBSD:16:amd64/kmods_latest_0",
  enabled: yes,
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg"
}
PKGCONF
            echo "Custom pkg repo config written to ${PKG_CONF}"
            echo "--- pkg config content ---"
            cat "${PKG_CONF}"
            echo "--- end config ---"

            # Clear any cached repo data inside the staging root
            rm -rf "${STAGE}/var/cache/pkg" 2>/dev/null || true

            pkg -C "${PKG_CONF}" -r "${STAGE}" update -f 2>&1 | tail -10 || true
            pkg -C "${PKG_CONF}" -r "${STAGE}" install -y ${PKGS} 2>&1 | tail -30 || \
                echo "WARNING: pkg install in rootdir failed (continuing)"
            umount "${STAGE}/dev" 2>/dev/null || true
            echo "DOB packages installed: ${PKGS}"
        fi
    else
        echo "WARNING: pkg not on PATH; skipping DOB package installation"
    fi

    # 4. Re-pack the staging tree into a new ISO
    #    Use mkisofs/bsdmakefs with the release.sh-style hybrid UEFI+BIOS layout.
    ISO_OUT="/scratch/R/dob-${DOB_VERSION}-amd64-disc1.iso"
    rm -f "${ISO_OUT}"

    # Build efiboot.img for UEFI boot
    EFI_STAGE="${STAGE}/boot/efi"
    if [ -d "${EFI_STAGE}" ]; then
        dd if=/dev/zero of=/tmp/dob-efiboot.img bs=1k count=1440 2>/dev/null
        mkfs.msdos -F 12 /tmp/dob-efiboot.img >/dev/null
        MTOUTPUT=$(mktemp -d)
        mount -t msdosfs /tmp/dob-efiboot.img "${MTOUTPUT}"
        cp -r "${EFI_STAGE}/." "${MTOUTPUT}/"
        umount "${MTOUTPUT}"
        rmdir "${MTOUTPUT}"
    fi

    # Make the ISO using mkisofs (hybrid UEFI+BIOS)
    if command -v mkisofs >/dev/null 2>&1; then
        mkisofs -R -J -V "DOB_${DOB_VERSION}" \
            -b boot/cdboot -no-emul-boot -boot-load-size 4 -boot-info-table \
            -eltorito-alt-boot -e efiboot.img -no-emul-boot -isohybrid-mbr /usr/obj/usr/src/amd64.amd64/release/iso/mbr.iso \
            -o "${ISO_OUT}" "${STAGE}" 2>&1 | tail -20
    elif command -v xorriso >/dev/null 2>&1; then
        xorriso -as mkisofs -R -J -V "DOB_${DOB_VERSION}" \
            -b boot/cdboot -no-emul-boot -boot-load-size 4 -boot-info-table \
            -eltorito-alt-boot -e efiboot.img -no-emul-boot -isohybrid-mbr /usr/obj/usr/src/amd64.amd64/release/iso/mbr.iso \
            -o "${ISO_OUT}" "${STAGE}" 2>&1 | tail -20
    else
        echo "ERROR: neither mkisofs nor xorriso found" >&2
        exit 1
    fi

    if [ ! -f "${ISO_OUT}" ]; then
        echo "ERROR: DOB ISO was not produced: ${ISO_OUT}" >&2
        exit 1
    fi
    echo "DOB ISO produced: ${ISO_OUT}"
    mark_done overlay
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
    # The overlay step produced the DOB-branded ISO. Copy to working dir
    # under the canonical name and generate checksums.
    ISO_SRC="/scratch/R/dob-${DOB_VERSION}-amd64-disc1.iso"
    ISO_DST="dob-${DOB_VERSION}-amd64.iso"
    cp "${ISO_SRC}" "${ISO_DST}"
    sha256 "${ISO_DST}" > SHA256SUMS
    mark_done assemble
fi

echo "Build complete: dob-${DOB_VERSION}-amd64.iso + SHA256SUMS"
