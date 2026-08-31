# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Identity

DOB is a **FreeBSD-based operating system distribution** (version 1.0) with a Fruitiger Aero visual identity, a reddish-tinted icon and theme system, a branded boot/desktop splash, and a custom Qt graphical installer. It is built as a **thin overlay on stock FreeBSD 14.2-RELEASE** — FreeBSD supplies the kernel, base utilities, and package manager; DOB supplies the visual identity, theming, splash, installer, and default app bundle.

Outputs: `dob-1.0-amd64.iso` (hybrid UEFI+BIOS live/install) and `dob-1.0-arm64.img` (RPi/UTM).

## Commands

```bash
# Shell syntax validation (works on any host with bash)
bash -n dob-layer/build/build.sh && bash -n dob-layer/build/build-arm.sh && echo OK

# Build the installer (cross-platform, requires Qt6 Widgets)
cmake -S dob-layer/installer -B build-installer
cmake --build build-installer

# Run installer unit test
cmake --build build-installer --target plan_install_test
./build-installer/plan_install_test
```

Full ISO/image generation requires a **FreeBSD 14.2-RELEASE host** (bare metal or VM). On macOS, use UTM to run a FreeBSD VM, then build inside it. The `build.sh`/`build-arm.sh` scripts document the real `release.sh`/`mkimg` invocations as commented blocks.

## Architecture

Three clear layers, all under `dob-layer/`:

- **Overlay** (`dob-layer/overlay/`): Filesystem overlay injected into the FreeBSD image root. Contains brand tokens (`etc/dob.conf` — single source of truth for brand colors #C0102A, #E63950, #7A0A1E), SVG art sources, Plasma theme + Kvantum config, DOB-Red icon theme, static boot splash PNGs + animated QML desktop splash, boot/loader/rc config snippets, and the installer `.desktop` shortcut.

- **Installer** (`dob-layer/installer/`): Self-contained Qt6 Widgets C++17 app (CMake 3.16+). `QWizard` subclass with four pages (Welcome → Disk → User → Summary). Shared `InstallConfig` data model. Pure `planInstall()` function returns ordered install steps (unit-testable without disk I/O). `InstallEngine::apply()` does validate-then-write execution with auto-rollback on failure.

- **Build Pipeline** (`dob-layer/build/`): Bash scripts orchestrating FreeBSD `release(8)` and `mkimg`. `pins.sh` pins FreeBSD release, package set, and DOB version (sourced by other scripts). `DOB-release.conf` is the `release.sh` configuration. `dob-src.conf` disables in-tree LLVM/Clang builds.

- **Package Manifest** (`dob-layer/pkg-list/dob-manifest.pkglist`): FreeBSD ports to install (plasma6, plasma6-sddm, firefox, libreoffice, vlc, dolphin, kvantum, llvm18, dob-installer).

## Key Conventions

- Brand tokens in `overlay/etc/dob.conf` are the **single source of truth** — all art, theme, and installer files reference these hex values. When adding new visual assets, update `dob.conf` first.
- The installer cleanly separates planning (`planInstall`, pure function) from execution (`InstallEngine`, side effects with rollback) — unit tests target only the planning layer.
- All DOB content lives under `dob-layer/` and is never mixed with FreeBSD source trees.
- No CI/CD is configured; no application tests exist beyond the installer's `plan_install_test`.

## Reference Documents

- `docs/superpowers/specs/2026-08-23-dob-freebsd-os-design.md` — authoritative design specification
- `docs/superpowers/plans/2026-08-23-dob-build-plan.md` — step-by-step implementation plan
