# DOB — A Fruitiger Aero FreeBSD Distribution

**Date:** 2026-08-23
**Status:** Approved design (pre-implementation)
**Build approach:** FreeBSD `release(8)` + thin DOB overlay layer

## 1. Overview

DOB is a FreeBSD-based operating system with a Fruitiger Aero aesthetic, a
reddish-tinted icon and theme system, a branded boot/desktop splash showing the
OS name, and a custom commercial-grade graphical installer. The first deliverable
is a **bootable, themed ISO** (x86_64) plus a separate **ARM64 disk image**,
targeting a general home desktop audience.

DOB is built as a **thin, well-defined overlay** on top of stock FreeBSD. FreeBSD
supplies the kernel, base utilities, package manager, and filesystems. The DOB
layer supplies the visual identity, theming, splash, custom installer, and the
default application bundle. This keeps the build reproducible and the scope bounded.

## 2. Goals & Non-Goals

### Goals
- Bootable x86_64 ISO (hybrid UEFI + BIOS) with live + install capability.
- Bootable ARM64 `.img` (Raspberry Pi / UTM) with the same DOB layer.
- Fruitiger Aero visual identity with a consistent reddish tint on glossy
  highlights, icon glows, and active states.
- Branded boot splash and desktop splash showing the OS name "DOB".
- Custom graphical (Qt) installer that is easy to use and commercially polished.
- Preinstalled general home desktop bundle: web browser, office suite, media
  player, file manager, basic utilities.

### Non-Goals (first phase)
- Building FreeBSD world/kernel from heavily modified source (use stock src).
- Legacy 32-bit x86 or non-ARM64 non-x86_64 architectures.
- A full custom package repository (use FreeBSD pkg + a small DOB-local set).
- Mobile / touch-first UX.

## 3. Architecture — the DOB Layer

FreeBSD's `release(8)` machinery (`release.sh` / `make release`) builds the base
world, kernel, and pkg set. DOB supplies configuration and a "local" overlay that
is injected into the built image via the `release` local mechanism
(`src/release/tools/` plus a local package set and overlay tarball).

Repository layout:

```
freebsd-src/                 # stock FreeBSD src, vendored at a pinned version
  release/
    tools/DOB.conf          # release.sh config: DOB name, pkg set, overlay
dob-layer/
  overlay/                  # files dropped into image root
    usr/local/share/dob/    # theme, icons, splash, wallpapers, installer assets
    etc/                    # default rc/loader config snippets (overlays)
  pkg-list/
    dob-manifest.pkglist    # DOB package manifest (plasma6, apps, installer)
  art/                      # source SVGs: logo, splash, wallpaper, key icons
  installer/                # custom Qt installer source
  build/
    build.sh                # wraps release.sh + mkimg for both targets
    pins.sh                 # version pins (FreeBSD rel, pkg set, art/installer)
```

Two output artifacts, both produced by `build/build.sh`:
- **x86_64 ISO** — hybrid UEFI+BIOS live/install media.
- **ARM64 disk image** — `.img` via `mkimg`, for RPi/UTM; separate build, same DOB layer.

Responsibility split:
- **FreeBSD owns:** kernel, base utilities, pkg, ZFS/UFS, boot blocks, loader.
- **DOB owns:** theme, reddish icon set, boot + desktop splash, custom installer,
  default app bundle, branding.

## 4. Visual Identity (Aero + Red)

- **Palette:** classic Aero glassy gradients and sky-blue glass highlights, with
  the primary accent shifted to a **reddish tint** (deep crimson → warm red). Red
  is a **confident accent** on a blue-dominant chrome: applied to glossy
  highlights, icon glows, and active/selection states. It goes bold only at the
  **desktop and active UI** — the boot/loader/splash stages stay Aero-blue with a
  subtle red aurora (no red frame at boot). Backgrounds keep Aero sky-blue glass
  with a subtle red aurora.
- **Original signature pieces (authored as SVG):** DOB wordmark/logo, boot splash
  artwork (OS name on Aero glass), desktop splash (animated, red-bold), **desktop
  wallpaper as a mountain image** (Aero glass treatment, blue with subtle red
  aurora), installer branding, and roughly 12 key app icons (network, storage,
  power, browser, files, etc.) with a red-gloss treatment.
- **Retinted free set:** Breeze/Oxygen-derived icon set batch-applied with a
  red-gloss treatment for the long-tail icons.
- **Theme:** a custom Plasma Look-and-Feel + Kvantum/Qt style delivering glass
  blur, glossy buttons, and Aero window decorations. Set as the default for both
  live and installed systems.

## 5. Boot & Splash Flow

The boot/loader/splash stages stay Aero-blue with a subtle red aurora. Red goes
bold only once the desktop and active UI are up.

1. **EFI/BIOS boot** → FreeBSD `loader.efi` themed with the DOB logo, configured to
   **autoboot with zero delay and no menu** — no loader options, no FreeBSD
   default-menu prompt, no timeout. The device boots straight into the OS; the DOB
   blue logo may flash briefly, then control passes immediately to the kernel.
   (Tradeoff: no on-device recovery entry at boot — recovery is via reinstall
   media, the standard consumer-OS tradeoff.)
2. **Kernel boot** → framebuffer boot splash via `vt`: a **static** PNG (DOB name +
   Aero glass, blue with subtle red aurora). Kernel-stage animation is not possible
   on `vt`, so the splash is static; verbose boot output is hidden.
3. **Live desktop** → Plasma launches with an **animated** DOB desktop splash
   (OS name, red-bold gloss) — this is where red first goes bold — then auto-presents
   the **DOB installer** on first boot (also available as an "Install DOB" desktop
   shortcut).
4. **Installed boot** → same autoboot loader + static blue splash, then the animated
   desktop splash, then Plasma login.

## 6. Custom Installer (Qt)

A graphical wizard, KDE/Qt native, Aero-red themed. The installer runs inside the
live environment and **clones the prebuilt live root** to the target disk (offline,
no network pkg fetch — fast, commercial feel).

Steps:

1. **Welcome** — DOB branding, language and keyboard selection.
2. **Disk** — **guided only**: "use entire disk" with a ZFS (default) or UFS radio.
   No custom partition editor. Clear, explicit red warning before any destructive
   write.
3. **User** — name, password, hostname, autologin toggle.
4. **Summary** — review selections → install (clone the prebuilt image root, apply
   the DOB layer, create users, write boot blocks).
5. **Done** — prompt to reboot.

Error handling: **validate-then-write** — every selection validated before any disk
write; writes to the target happen only after explicit confirmation on Summary. On
failure the installer **auto-rolls-back** (unmounts / cleans the target) and shows a
clear error dialog with an accessible log file.

## 7. Build & Release Pipeline

- **Build host:** FreeBSD (14-RELEASE or latest stable) running as a VM on macOS
  (bhyve/UTM) or in CI. Building world requires FreeBSD; macOS cannot build it
  directly.
- **`build/build.sh`:** checks out pinned FreeBSD src + ports, runs `release.sh`
  with `DOB.conf`, injects the DOB layer + pkg-list, and produces the ISO (x86)
  and `.img` (ARM64).
- **Pinning:** FreeBSD version, pkg set, and DOB art/installer are all
  version-pinned for reproducible builds.
- **Output:** `dob-1.0-amd64.iso`, `dob-1.0-arm64.img`, plus a `SHA256SUMS` file.

## 8. Testing / Acceptance

- Boot the x86_64 ISO in a VM (UTM/VirtualBox): loader → splash → live Plasma →
  installer → installed reboot, all themed.
- Boot the ARM64 `.img` in UTM / flash to Raspberry Pi: same flow.
- Verify reddish-tint icons render across Plasma and the file manager; glass theme
  active by default.
- Installer exercised on: clean install, custom-partition path, and a failure path
  (e.g. target disk full) showing a clear error.
- "Easy to use" check: a first-time user can complete installation without docs.

## 9. Development Approach

Implementation follows `/superpowers:subagent-driven-development`. The work is
decomposed into independent, well-bounded units (art/theme, overlay + pkg-list,
boot/splash config, custom installer, build pipeline, acceptance test rig), each
implemented and verified before integration.
