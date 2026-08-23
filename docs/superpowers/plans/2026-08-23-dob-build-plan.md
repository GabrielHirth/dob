# DOB Build Plan — FreeBSD + Fruitiger Aero (bootable ISO + ARM64 image)

**Source of authority:** `docs/superpowers/specs/2026-08-23-dob-freebsd-os-design.md`
**Deliverable:** A complete, buildable DOB source tree that produces a themed
x86_64 live/install ISO and an ARM64 disk image on a FreeBSD build host, with a
custom Qt installer and a reddish-tinted Fruitiger Aero identity.

## Global Constraints

- DOB is a **thin overlay on stock FreeBSD**, built via `release(8)`. Never fork
  or modify FreeBSD world/kernel source. All DOB-authored content lives under
  `dob-layer/`.
- The **reddish tint** is mandatory and consistent: deep crimson → warm red
  applied to glossy highlights, icon glows, and active states. Accent hex
  primary: `#C0102A`, secondary highlight: `#E63950`, deep: `#7A0A1E`.
- Branding name is **DOB**, shown on the boot splash and desktop splash.
- Installer is **custom Qt**, graphical, runs in the live environment, reuses the
  prebuilt root (offline install, no network pkg fetch during install).
- Every artifact is **authorable and verifiable on macOS**; only the final image
  generation (Task 12) requires a FreeBSD build host and is documented, not run.
- Repo layout, filenames, and the pinned brand tokens above are authoritative and
  must match exactly across tasks.

## Repository layout (all tasks conform)

```
dob-layer/
  overlay/
    usr/local/share/dob/
      theme/            (Plasma Look-and-Feel, Kvantum, colors, wallpaper)
      icons/            (red-gloss icon set + index.theme)
      splash/           (boot splash + desktop splash assets)
      installer/        (Qt installer resources)
      art/              (source SVGs: logo, wallpaper, key icons)
    etc/
      dob.conf          (DOB brand tokens: name, colors)
      rc.conf.dob       (live autostart of installer / plasma)
      loader.conf.dob   (themed loader config snippet)
  pkg-list/
    dob-manifest.pkglist
  installer/            (Qt installer C++ source, CMakeLists.txt)
  build/
    pins.sh             (FreeBSD rel, pkg set, art/installer versions)
    build.sh            (wraps release.sh for x86 ISO)
    build-arm.sh        (mkimg for ARM64 .img)
    DOB-release.conf    (release.sh config)
    README.md
docs/superpowers/plans/2026-08-23-dob-build-plan.md
docs/superpowers/specs/2026-08-23-dob-freebsd-os-design.md
```

---

## Task 1 — Repository scaffold and brand tokens

Create the `dob-layer/` directory tree above (empty placeholder dirs plus real
files where specified). Author `dob-layer/overlay/etc/dob.conf` containing the
brand tokens: name `DOB`, accent `#C0102A`, highlight `#E63950`, deep `#7A0A1E`,
and a one-line summary string. Add a `.gitignore` ignoring build output (ISO,
img, work dirs). Commit.

**Why:** every later task drops files into this tree or reads `dob.conf`.

## Task 2 — Brand art: logo, wallpaper, splash source SVGs

Author original SVG source art in `dob-layer/overlay/usr/local/share/dob/art/`:
- `logo.svg` — DOB wordmark on Aero glass with red tint.
- `wallpaper.svg` — Aero sky-blue glass with subtle red aurora.
- `boot-splash.svg` — full-screen DOB name + Aero glass, red-tinted, 16:9.
- `desktop-splash.svg` — DOB name centered, red gloss, for Plasma splash.
- `key-icons/` — ~12 original 64×64 SVG app icons (network, storage, power,
  browser, files, audio, video, settings, user, search, update, terminal) with
  red-gloss treatment.
Use the brand tokens from `dob.conf`. Commit.

**Why:** signature original pieces per spec §4; source for rasterized splash.

## Task 3 — Reddish-tinted icon set + index.theme

Create `dob-layer/overlay/usr/local/share/dob/icons/`:
- `icons/DOB-Red/index.theme` — an icon theme named `DOB-Red` (Inherits=Breeze,
  Directories=...), referencing the 12 original key icons from Task 2 for those
  names and falling back to Breeze for the rest.
- A documented `icons/retint.sh` that, given a Breeze/Oxygen source dir and the
  brand tokens, batch-applies a red gloss (hue-shift + highlight overlay) to
  produce the long-tail icon set. The script must be runnable; include a small
  generated sample so the tree is self-contained without a Breeze checkout.
Keep the script dependency-light (ImageMagick or rsvg-based, documented). Commit.

**Why:** spec §4 retinted-free-set requirement; reproducible tint pipeline.

## Task 4 — Plasma Look-and-Feel + Kvantum/Qt glass theme

Author the DOB theme under `dob-layer/overlay/usr/local/share/dob/theme/`:
- `lookandfeel/DOB/` — Plasma Look-and-Feel metadata + `colors` file encoding the
  red accent (`#C0102A`) as the active/selection color, glass blur enabled.
- `kvantum/DOB-Red.kvconfig` — Kvantum config giving glossy buttons and red
  highlight.
- `theme/metadata.desktop` declaring the theme; `theme/apply.sh` that sets it as
  default (writes `~/.config` entries + a system default drop-in under `overlay`
  so live + installed both default to DOB).
All colors use the brand tokens. Commit.

**Why:** the Aero-glass desktop identity; default applied in Task 10/11.

## Task 5 — Boot & desktop splash assets and loader config

- Rasterize `boot-splash.svg` and `desktop-splash.svg` to PNG at common
  resolutions (e.g. 1920×1080, 1366×768) into
  `dob-layer/overlay/usr/local/share/dob/splash/`.
- Author `dob-layer/overlay/etc/loader.conf.dob`: sets the FreeBSD loader logo to
  the DOB logo, hides the boot menu text where safe, applies red-frame branding
  (loader menu theme snippet), and references the boot splash.
- Author `dob-layer/overlay/etc/rc.conf.dob`: enables the `vt` framebuffer splash
  pointing at the DOB boot splash, and (for live) triggers Plasma + DOB desktop
  splash on first boot.
Commit. **Why:** spec §5 boot/splash flow.

## Task 6 — Custom Qt installer: project skeleton

Scaffold the installer under `dob-layer/installer/`: `CMakeLists.txt` (Qt6
Widgets, find_package), `main.cpp`, and an `Installer` class splitting the
wizard into pages. Define the data model: `InstallConfig` (language, keymap,
disk target, fs type [ZFS|UFS], user name, password, hostname, autologin). Add a
`resources.qrc` wiring `dob-layer/overlay/usr/local/share/dob/installer/`
branding. The app must compile (macOS Qt6 or a stub) and show an empty
branded window titled "DOB Installer". Commit.

**Why:** foundation for Tasks 7–9; buildable now to prove the harness.

## Task 7 — Installer pages: Welcome, Disk, User, Summary

Implement the wizard pages over `InstallConfig`:
- **Welcome:** DOB branding, language + keyboard selectors (static lists;
  English default).
- **Disk:** guided "use entire disk" (ZFS or UFS radio) + advanced custom
  partition toggle; explicit red warning text before any destructive write.
  Validation: must pick a non-empty target.
- **User:** name, password (+confirm), hostname, autologin checkbox; validation
  on password match and non-empty name.
- **Summary:** read-only review of all selections.
Each page validates before `Next`. Commit. **Why:** spec §6 steps 1–4.

## Task 8 — Installer engine: apply to target disk (offline)

Implement `InstallEngine` that, on "Install" from Summary:
- Copies the prebuilt live root to the target (simulated/local-copy path that
  works without root where possible, real device path behind a guarded
  `#ifdef DOB_REAL_DISK` / root check).
- Applies the DOB layer (theme default, users, hostname) to the copied root.
- Writes a boot-block placeholder step with clear logging.
- Rollback-safe: no writes to target until user confirms on Summary; on failure,
  logs to an accessible file and shows a clear error dialog (exercise the
  disk-full path with a clear message).
Provide a unit-testable pure function `planInstall(config) -> ordered steps` with
tests (no disk IO). Commit. **Why:** spec §6 install step + error handling.

## Task 9 — Installer branding + install-into-image packaging

- Add DOB installer branding assets (logo, red frame, title) under
  `dob-layer/overlay/usr/local/share/dob/installer/`.
- Make the installer build into the image: add it to
  `dob-layer/pkg-list/dob-manifest.pkglist` as a local port/pkg, and add an
  autostart entry (`overlay/etc/rc.conf.dob` already launches live; add a
  `.desktop` autostart for "Install DOB" on the live desktop and a first-boot
  trigger).
- Ensure `dob-layer/installer/CMakeLists.txt` installs to
  `/usr/local/bin/dob-installer` and resources to the DOB share dir.
Commit. **Why:** spec §5 step 3 + §6.

## Task 10 — Package manifest + FreeBSD release config

- Author `dob-layer/pkg-list/dob-manifest.pkglist`: KDE Plasma 6, the DOB
  installer (local), and home-desktop apps — web browser (e.g. Falkon/Firefox),
  office (LibreOffice), media player (VLC), file manager (Dolphin, part of
  Plasma), utilities. One package per line, commented groups.
- Author `dob-layer/build/DOB-release.conf`: `release.sh` config naming DOB,
  pointing at the pkg-list and the `dob-layer/overlay` as the local overlay,
  setting UEFI+BIOS hybrid for x86.
- Author `dob-layer/build/pins.sh`: pin FreeBSD release (14-RELEASE or latest
  stable), pkg set version, art/installer versions; sourceable by build scripts.
Commit. **Why:** spec §3 + §7; wires DOB layer into release(8).

## Task 11 — Build scripts (x86 ISO + ARM64 img) + README

- `dob-layer/build/build.sh`: sources `pins.sh`, checks out pinned FreeBSD
  src+ports, runs `release.sh` with `DOB-release.conf`, injects overlay + pkg-list,
  produces `dob-1.0-amd64.iso` (hybrid UEFI+BIOS) and a `SHA256SUMS`.
- `dob-layer/build/build-arm.sh`: uses `mkimg` to produce `dob-1.0-arm64.img`
  (RPi/UTM layout) from the same DOB layer; documents the ARM device tree needs.
- `dob-layer/build/README.md`: exact FreeBSD build-host prerequisites (VM on
  macOS via bhyve/UTM), how to run each script, and expected outputs.
Scripts must be syntax-valid (`bash -n`) and clearly document the host requirement
(they are NOT executed on macOS). Commit. **Why:** spec §7.

## Task 12 — Manual build + acceptance verification (FreeBSD host)

**Environment-dependent — performed on a FreeBSD build host, not macOS.**
Run `build.sh` to produce `dob-1.0-amd64.iso`; boot it in a VM (UTM/VirtualBox):
loader → red-tinted boot splash → live Plasma (DOB theme active) → DOB installer
→ installed reboot. Build `dob-1.0-arm64.img`; boot in UTM / flash to RPi: same
flow. Verify reddish-tint icons render in Plasma + file manager; installer clean,
custom-partition, and disk-full failure paths show clear errors. Record results
in `dob-layer/build/ACCEPTANCE.md`.

**If no FreeBSD host is available:** this task is replaced by a documented
dry-run — `bash -n` on all scripts, a tree manifest check that every path the
spec/plan references exists, and `ACCEPTANCE.md` noting the build host requirement.
This repo delivers the complete buildable source; image generation is the one
step needing FreeBSD. Commit whichever applies.
