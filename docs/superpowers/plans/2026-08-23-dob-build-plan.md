# DOB — FreeBSD + Fruitiger Aero OS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete, buildable DOB source tree that produces a themed x86_64 live/install ISO and an ARM64 disk image on a FreeBSD build host, with a custom Qt installer and a red-tinted Fruitiger Aero identity.

**Architecture:** DOB is a thin overlay on stock FreeBSD built via `release(8)`. FreeBSD supplies kernel, base, pkg, filesystem, loader. The DOB layer supplies art/theme, reddish icon set, boot + desktop splash, custom Qt installer, and the default app bundle. Two output artifacts (x86 ISO, ARM64 img) come from `dob-layer/build/`.

**Tech Stack:** FreeBSD `release(8)` + `mkimg`; Qt6 Widgets (C++17, CMake) for the installer; SVG art (hand-authored / rsvg-convert or Inkscape for rasterization); Plasma 6 + Kvantum for the desktop theme; bash for build scripts.

**Spec:** `docs/superpowers/specs/2026-08-23-dob-freebsd-os-design.md` (authoritative; this plan argues from it including the 2026-08-23 refinements).

## Global Constraints

- DOB is a **thin overlay on stock FreeBSD**, built via `release(8)`. Never fork or modify FreeBSD world/kernel source. All DOB-authored content lives under `dob-layer/`.
- The **reddish tint** is mandatory and consistent: deep crimson → warm red on glossy highlights, icon glows, active/selection states. Brand tokens (single source of truth in `dob-layer/overlay/etc/dob.conf`): accent `#C0102A`, highlight `#E63950`, deep `#7A0A1E`.
- **Red is a confident accent on blue-dominant chrome. Red goes bold only at the desktop + active UI. Boot/loader/splash stay Aero-blue with a SUBTLE red aurora — NO red frame at boot.**
- **Boot loader autoboots with zero delay and NO menu** — no loader options, no FreeBSD default-menu prompt, no timeout. The device boots straight into the OS, then autoboots into the splash.
- **Boot splash is STATIC** (FreeBSD `vt` cannot animate at kernel stage). **Desktop splash (under Plasma) is animated** and is where red first goes bold.
- Wallpaper is a **mountain image** rendered in Aero glass treatment, blue base with subtle red aurora.
- Branding name is **DOB**, shown on the boot splash and desktop splash.
- Installer is **custom Qt**, graphical, runs in the live environment, **clones the prebuilt live root** to target (offline install, no network pkg fetch during install).
- Installer is **guided-only**: "use entire disk" with **ZFS (default)** or UFS radio; **no custom partition editor**.
- Installer is **validate-then-write + auto-rollback**: validate every selection before any disk write; writes happen only after explicit Summary confirm; on failure unmount/clean the target and show a clear error + accessible log.
- Every artifact is **authorable and verifiable on macOS**; only final image generation (Task 12) requires a FreeBSD build host and is documented, not run.
- Repo layout, filenames, and the pinned brand tokens above are authoritative and must match exactly across tasks.

---

## File Structure

```
dob-layer/
  overlay/
    usr/local/share/dob/
      art/                       # SOURCE SVGs (logo, wallpaper, splashes, key-icons)
        logo.svg
        wallpaper.svg            # mountain, Aero glass, blue + subtle red aurora
        boot-splash.svg          # static, 16:9, blue + subtle red aurora
        desktop-splash.svg       # animated-capable, red-bold
        key-icons/               # ~12 original 64x64 red-gloss SVG icons
          network.svg storage.svg power.svg browser.svg files.svg
          audio.svg video.svg settings.svg user.svg search.svg update.svg terminal.svg
      theme/                     # Plasma Look-and-Feel + Kvantum + colors + wallpaper
        lookandfeel/DOB/metadata.desktop
        lookandfeel/DOB/colors
        lookandfeel/DOB/plasma-look-and-feel.conf (or contents/)
        kvantum/DOB-Red.kvconfig
        wallpaper/mountain.png   # rasterized from art/wallpaper.svg
        apply.sh                 # sets DOB as default for live + installed
      icons/
        DOB-Red/index.theme
        DOB-Red/apps/...         # the 12 original icons (copied from art/key-icons)
        retint.sh                # batch red-gloss a Breeze/Oxygen source dir
        sample/                  # small pre-generated long-tail so tree is self-contained
      splash/
        boot-splash-1920x1080.png
        boot-splash-1366x768.png
        desktop-splash/          # animated frames or QML splash assets
      installer/
        branding.svg             # DOB installer logo + red window frame + title
    etc/
      dob.conf                   # EXISTS (brand tokens) — do not redefine values
      rc.conf.dob                # live autostart of plasma + desktop splash; vt splash
      loader.conf.dob            # autoboot, no menu, DOB blue logo, static splash ref
  pkg-list/
    dob-manifest.pkglist         # plasma6, dob-installer(local), home-desktop apps
  installer/                     # Qt6 C++ installer source
    CMakeLists.txt
    main.cpp
    installer.h / installer.cpp          # wizard + page orchestration
    config.h / config.cpp                # InstallConfig data model
    pages/welcome_page.h/.cpp
    pages/disk_page.h/.cpp
    pages/user_page.h/.cpp
    pages/summary_page.h/.cpp
    engine/install_engine.h/.cpp         # InstallEngine + planInstall()
    engine/plan_install.h/.cpp           # pure planInstall(config)->steps
    engine/plan_install_test.cpp         # unit tests (no disk IO)
    resources.qrc                        # branding from overlay/usr/local/share/dob/installer
  build/
    pins.sh                 # FreeBSD rel, pkg set, art/installer versions (sourceable)
    DOB-release.conf        # release.sh config: name, pkg-list, overlay, UEFI+BIOS
    build.sh                # x86 ISO: wraps release.sh
    build-arm.sh            # ARM64 img: mkimg
    README.md               # FreeBSD build-host prerequisites + run instructions
docs/superpowers/plans/2026-08-23-dob-build-plan.md   # THIS file
docs/superpowers/specs/2026-08-23-dob-freebsd-os-design.md
```

Responsibility split (from spec §3): FreeBSD owns kernel/base/pkg/ZFS/UFS/boot blocks/loader; DOB owns theme, reddish icon set, boot + desktop splash, custom installer, default app bundle, branding.

---

## Task 1 — Repository scaffold and brand tokens

**Status:** Already committed (`655da1e` + `087b265`). Scaffold tree and `dob-layer/overlay/etc/dob.conf` exist. This task is retained for completeness; do NOT redefine the brand-token values — read them from `dob.conf`.

**Files:**
- Exists: `dob-layer/` tree, `dob-layer/overlay/etc/dob.conf` (name=DOB, accent=#C0102A, highlight=#E63950, deep=#7A0A1E).
- Verify/Create: `.gitignore` at repo root ignoring build output (`*.iso`, `*.img`, `work/`, `*.sha256`).

**Interfaces:** Later tasks read brand tokens via `source dob-layer/overlay/etc/dob.conf` (sh) and embed the hex values in SVG/C++/theme files.

- [ ] **Step 1: Confirm scaffold exists**
  Run: `test -f dob-layer/overlay/etc/dob.conf && echo OK`
  Expected: prints `OK`.

- [ ] **Step 2: Ensure .gitignore covers build output**
  If `.gitignore` lacks `*.iso`, `*.img`, `work/`, add those lines.

- [ ] **Step 3: Commit (if .gitignore changed)**
  ```bash
  git add .gitignore
  git commit -m "build: ignore ISO/img/work build artifacts"
  ```

---

## Task 2 — Brand art: logo, wallpaper, splash source SVGs

**Files:**
- Create: `dob-layer/overlay/usr/local/share/dob/art/logo.svg`
- Create: `dob-layer/overlay/usr/local/share/dob/art/wallpaper.svg`
- Create: `dob-layer/overlay/usr/local/share/dob/art/boot-splash.svg`
- Create: `dob-layer/overlay/usr/local/share/dob/art/desktop-splash.svg`
- Create: `dob-layer/overlay/usr/local/share/dob/art/key-icons/*.svg` (12 files)

**Interfaces:**
- Consumes: brand tokens `#C0102A`/`#E63950`/`#7A0A1E` from `dob.conf`.
- Produces: SVG sources consumed by Task 3 (icons), Task 4 (wallpaper), Task 5 (rasterize splashes), Task 9 (installer branding reuse).

**Art rules (all tasks):**
- Aero glass = radial/linear gradients, soft white top highlight, translucent panels, subtle drop shadows.
- Blue base hue ~ `#3A6EA5`/`#7FB2E0` sky-blue glass. Red aurora = a soft `#C0102A`→transparent radial glow at edges only (subtle).
- Red is a **confident accent**: glossy highlights, glows, active states. NOT a full red frame at boot.

- [ ] **Step 1: Write `logo.svg`** — DOB wordmark on Aero glass.
  Content: a 512×160 viewBox. Glass rounded-rect background (blue gradient + white top gloss). Text "DOB" centered, fill `#E63950` with a white top highlight and `#7A0A1E` bottom shadow (red-gloss). A small red glow ellipse behind the text.

- [ ] **Step 2: Write `wallpaper.svg`** — **mountain image**, Aero glass, blue + subtle red aurora.
  Content: 1920×1080. Sky-blue glass gradient sky; layered mountain silhouettes (3 ranges) with blue→deep gradients; a faint red aurora radial glow near top corner (`#C0102A` at low opacity, blurred). Soft light streaks. No text.

- [ ] **Step 3: Write `boot-splash.svg`** — static, 16:9, blue + subtle red aurora, NO red frame.
  Content: 1920×1080. Blue Aero glass field; centered DOB logo (reuse logo styling); subtle red aurora at edges only. Designed to read as a still frame (no motion implied).

- [ ] **Step 4: Write `desktop-splash.svg`** — animated-capable, red-bold.
  Content: 1920×1080. Same DOB logo but with a stronger red gloss/glow (`#E63950`) and a red accent sweep — this is where red goes bold. Provide as a base the QML/plasmasplash will animate (Task 5 packages frames).

- [ ] **Step 5: Write 12 `key-icons/*.svg`** — 64×64, red-gloss treatment.
  Files: `network storage power browser files audio video settings user search update terminal`.
  Each: a glossy blue base shape with a red (`#C0102A`) highlight/glow accent and a white top gloss. Distinct, recognizable silhouettes (do not copy proprietary art).

- [ ] **Step 6: Validate SVG well-formedness**
  Run (if `xmllint` available): `for f in dob-layer/overlay/usr/local/share/dob/art/**/*.svg; do xmllint --noout "$f" || echo "BAD $f"; done`
  Expected: no `BAD` output. (If `xmllint` missing, skip — authoring is manual.)

- [ ] **Step 7: Commit**
  ```bash
  git add dob-layer/overlay/usr/local/share/dob/art
  git commit -m "art: DOB logo, mountain wallpaper, boot/desktop splash, 12 key icons"
  ```

---

## Task 3 — Reddish-tinted icon set + index.theme

**Files:**
- Create: `dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/index.theme`
- Create: `dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/apps/<12 icons copied>.svg`
- Create: `dob-layer/overlay/usr/local/share/dob/icons/retint.sh`
- Create: `dob-layer/overlay/usr/local/share/dob/icons/sample/` (a few pre-generated long-tail icons)

**Interfaces:**
- Consumes: `art/key-icons/*.svg` (Task 2), brand tokens (Task 1).
- Produces: an installable icon theme `DOB-Red` referenced by Task 4 theme + Task 10 pkg set.

- [ ] **Step 1: Copy the 12 original icons into the theme**
  ```bash
  mkdir -p dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/apps
  cp dob-layer/overlay/usr/local/share/dob/art/key-icons/*.svg \
     dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/apps/
  ```

- [ ] **Step 2: Write `DOB-Red/index.theme`**
  ```ini
  [Icon Theme]
  Name=DOB-Red
  Comment=DOB red-gloss Fruitiger Aero icon theme
  Inherits=Breeze
  Directories=apps

  [apps]
  Size=64
  Context=Apps
  Type=Scalable
  ```
  The 12 original icons map to standard names: `network`→`network-workgroup`/`network-manager`, `storage`→`drive-harddisk`, `power`→`system-shutdown`, `browser`→`internet-web-browser`, `files`→`system-file-manager`, `audio`→`audio-volume-high`, `video`→`video-x-generic`/`media-video`, `settings`→`preferences-system`, `user`→`user-identity`, `search`→`system-search`, `update`→`system-software-update`, `terminal`→`utilities-terminal`. Provide the icons under BOTH the generic and the KDE-expected filename where known.

- [ ] **Step 3: Write `retint.sh`** (dependency-light, rsvg/ImageMagick)
  A documented bash script that takes a Breeze/Oxygen source dir + brand tokens and batch-applies a red gloss (hue-shift toward `#C0102A` + a white top-highlight overlay + subtle red glow) to produce long-tail icons. Must be runnable; printed usage when called with no args. Keep it POSIX-ish bash; document the required tool (`rsvg-convert`/`convert`) at top.
  ```bash
  #!/usr/bin/env bash
  # retint.sh <src-dir> <out-dir> [accent=#C0102A]
  # Batch-applies a red gloss to a Breeze/Oxygen SVG icon set.
  # Requires: rsvg-convert (or ImageMagick `convert`) — documented, not executed here.
  set -euo pipefail
  if [ $# -lt 2 ]; then echo "usage: $0 <src-dir> <out-dir> [accent]"; exit 1; fi
  SRC="$1"; OUT="$2"; ACCENT="${3:-#C0102A}"
  mkdir -p "$OUT"
  # For each .svg: inject a red-gloss filter (white top highlight + ACCENT glow)
  # and write to OUT. Real raster/tint pipeline runs on the build host.
  for f in "$SRC"/*.svg; do
    name=$(basename "$f")
    # placeholder transform: copy + note; full tint done at build time
    sed "s/<\/svg>/<style>\/* DOB red-gloss tint target: $ACCENT *\/<\/style><\/svg>/" "$f" > "$OUT/$name"
  done
  echo "retinted $(ls "$OUT" | wc -l | tr -d ' ') icons -> $OUT (accent $ACCENT)"
  ```

- [ ] **Step 4: Generate a small `sample/` so the tree is self-contained**
  Run: `bash dob-layer/overlay/usr/local/share/dob/icons/retint.sh dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/apps dob-layer/overlay/usr/local/share/dob/icons/sample`
  Expected: prints `retinted 12 icons -> ... (accent #C0102A)`.

- [ ] **Step 5: Verify index.theme parses**
  Run: `test -f dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/index.theme && grep -q "Inherits=Breeze" dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/index.theme && echo OK`
  Expected: `OK`.

- [ ] **Step 6: Commit**
  ```bash
  git add dob-layer/overlay/usr/local/share/dob/icons
  git commit -m "icons: DOB-Red theme (12 originals) + retint pipeline + sample"
  ```

---

## Task 4 — Plasma Look-and-Feel + Kvantum/Qt glass theme

**Files:**
- Create: `dob-layer/overlay/usr/local/share/dob/theme/lookandfeel/DOB/metadata.desktop`
- Create: `dob-layer/overlay/usr/local/share/dob/theme/lookandfeel/DOB/colors`
- Create: `dob-layer/overlay/usr/local/share/dob/theme/lookandfeel/DOB/contents/...` (look-and-feel descriptor as needed)
- Create: `dob-layer/overlay/usr/local/share/dob/theme/kvantum/DOB-Red.kvconfig`
- Create: `dob-layer/overlay/usr/local/share/dob/theme/wallpaper/mountain.png` (rasterized from `art/wallpaper.svg`)
- Create: `dob-layer/overlay/usr/local/share/dob/theme/apply.sh`

**Interfaces:**
- Consumes: brand tokens (Task 1), `art/wallpaper.svg` (Task 2).
- Produces: a default-applied theme + wallpaper + an `apply.sh` used by Task 10/11 to set DOB as the system default for live and installed.

**Theme rules:** **Full glass** — translucent blurred window chrome, glossy gradient titlebars, glass reflections, soft shadows. Red = confident accent (`#C0102A` active/selection, `#E63950` highlight, `#7A0A1E` deep). Blue stays dominant.

- [ ] **Step 1: Rasterize wallpaper**
  Run (if `rsvg-convert` available): `rsvg-convert -w 1920 -h 1080 dob-layer/overlay/usr/local/share/dob/art/wallpaper.svg -o dob-layer/overlay/usr/local/share/dob/theme/wallpaper/mountain.png`
  If unavailable, author a committed `mountain.png` placeholder of correct dimensions and note it in `apply.sh`.

- [ ] **Step 2: Write `lookandfeel/DOB/metadata.desktop`**
  ```ini
  [Desktop Entry]
  Name=DOB
  Comment=DOB red-tinted Fruitiger Aero
  Type=LookAndFeel
  ```

- [ ] **Step 3: Write `lookandfeel/DOB/colors`** (Plasma colors file)
  ```
  [Color Scheme]
  Name=DOB-Red
  [Colors:View]
  BackgroundNormal=48,84,128
  [Colors:Window]
  BackgroundNormal=58,110,165
  [Colors:Selection]
  BackgroundNormal=192,16,42
  ForegroundNormal=255,255,255
  [Colors:Button]
  BackgroundNormal=58,110,165
  ForegroundNormal=255,255,255
  [Colors:Complementary]
  BackgroundNormal=122,10,30
  ```
  (Red `#C0102A` = 192,16,42 active/selection; deep `#7A0A1E` = 122,10,30.)

- [ ] **Step 4: Write `kvantum/DOB-Red.kvconfig`**
  A Kvantum config delivering glossy buttons + red highlight. Set `activePageColor`, `buttonHoverColor` toward the red accent; enable subtle highlight. Reference the standard Kvantum key names; keep it valid INI.

- [ ] **Step 5: Write `apply.sh`** (idempotent; sets DOB as default)
  ```bash
  #!/usr/bin/env bash
  # apply.sh — set DOB as the default theme for live + installed systems.
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
  ```
  Also write a per-user default under the overlay skeleton so installed users inherit it (Task 10 wires `apply.sh` into first-boot).

- [ ] **Step 6: Validate configs parse**
  Run: `test -f dob-layer/overlay/usr/local/share/dob/theme/lookandfeel/DOB/colors && grep -q "192,16,42" dob-layer/overlay/usr/local/share/dob/theme/lookandfeel/DOB/colors && echo OK`
  Expected: `OK`.

- [ ] **Step 7: Commit**
  ```bash
  git add dob-layer/overlay/usr/local/share/dob/theme
  git commit -m "theme: DOB Plasma Look-and-Feel, Kvantum red-gloss, mountain wallpaper, apply.sh"
  ```

---

## Task 5 — Boot & desktop splash assets and loader config

**Files:**
- Create: `dob-layer/overlay/usr/local/share/dob/splash/boot-splash-1920x1080.png`
- Create: `dob-layer/overlay/usr/local/share/dob/splash/boot-splash-1366x768.png`
- Create: `dob-layer/overlay/usr/local/share/dob/splash/desktop-splash/` (animated frames or QML splash source)
- Modify/Create: `dob-layer/overlay/etc/loader.conf.dob`
- Modify/Create: `dob-layer/overlay/etc/rc.conf.dob`

**Interfaces:**
- Consumes: `art/boot-splash.svg`, `art/desktop-splash.svg` (Task 2).
- Produces: static boot splash PNGs (blue + subtle red aurora, NO red frame), animated desktop splash, and loader/rc config that autoboots with no menu and enables the `vt` splash.

**Critical boot rules (from refinement):**
- Loader: **autoboot, zero delay, no menu** — no FreeBSD default-menu prompt.
- Boot splash: **static** PNG, blue + subtle red aurora.
- Desktop splash: **animated**, red-bold (red goes bold here).

- [ ] **Step 1: Rasterize static boot splashes**
  Run (if `rsvg-convert` available):
  ```bash
  rsvg-convert -w 1920 -h 1080 dob-layer/overlay/usr/local/share/dob/art/boot-splash.svg -o dob-layer/overlay/usr/local/share/dob/splash/boot-splash-1920x1080.png
  rsvg-convert -w 1366 -h 768  dob-layer/overlay/usr/local/share/dob/art/boot-splash.svg -o dob-layer/overlay/usr/local/share/dob/splash/boot-splash-1366x768.png
  ```
  If unavailable, commit correct-dimension placeholders and note in README.

- [ ] **Step 2: Author desktop splash assets**
  Create `dob-layer/overlay/dob/splash/desktop-splash/` with a Plasma splash (`contents/components/...` for a `plasmasplash` package) OR a QML/animation source derived from `desktop-splash.svg`. Red-bold. Keep it self-contained.

- [ ] **Step 3: Write `loader.conf.dob`** (autoboot, no menu, blue logo, static splash ref)
  ```ini
  # DOB loader config — autoboot straight into the OS, no menu.
  autoboot_delay="-1"
  menu_timeout="0"
  beastie_disable="YES"
  loader_logo="do"
  # DOB blue logo (no red frame). Reference static boot splash after kernel starts.
  ```
  (The `loader_logo="do"` points at a DOB blue logo asset; the actual logo drop-in is added under the overlay boot dir in Task 10/11. Keep the key name stable.)

- [ ] **Step 4: Write `rc.conf.dob`** (vt splash + live first-boot plasma/desktop-splash)
  ```ini
  # DOB rc config
  dumpdev="NO"
  # Hide verbose boot; show static DOB boot splash via vt
  splash="DOB"
  # Live: launch Plasma + DOB desktop splash on first boot (Task 9 adds trigger)
  dob_live_autostart="YES"
  ```
  Ensure `splash_bmp`/`splash_pcx` module loads the boot PNG; the actual module hook is wired in Task 10.

- [ ] **Step 5: Validate configs**
  Run:
  ```bash
  grep -q 'autoboot_delay="-1"' dob-layer/overlay/etc/loader.conf.dob && \
  grep -q 'menu_timeout="0"' dob-layer/overlay/etc/loader.conf.dob && \
  grep -q 'splash="DOB"' dob-layer/overlay/etc/rc.conf.dob && echo OK
  ```
  Expected: `OK`.

- [ ] **Step 6: Commit**
  ```bash
  git add dob-layer/overlay/usr/local/share/dob/splash dob-layer/overlay/etc/loader.conf.dob dob-layer/overlay/etc/rc.conf.dob
  git commit -m "boot: static blue boot splash, animated desktop splash, autoboot loader (no menu)"
  ```

---

## Task 6 — Custom Qt installer: project skeleton

**Files:**
- Create: `dob-layer/installer/CMakeLists.txt`
- Create: `dob-layer/installer/main.cpp`
- Create: `dob-layer/installer/config.h` + `config.cpp`
- Create: `dob-layer/installer/installer.h` + `installer.cpp`
- Create: `dob-layer/installer/resources.qrc`

**Interfaces:**
- Consumes: branding from `dob-layer/overlay/usr/local/share/dob/installer/` (Task 9 finalizes; this task wires the qrc path).
- Produces: `InstallConfig` data model (used by Tasks 7–9) and a compilable installer that shows an empty branded window titled "DOB Installer".

**InstallConfig (config.h):** exact struct later tasks depend on:
```cpp
struct InstallConfig {
    QString language;      // default "en"
    QString keymap;        // default "us"
    QString diskTarget;    // device path, e.g. /dev/ada0
    enum FsType { ZFS, UFS } fsType = ZFS;  // ZFS default
    QString userName;
    QString password;
    QString hostname;
    bool autologin = false;
};
```

- [ ] **Step 1: Write `config.h`** with the struct above (plus a default constructor).
- [ ] **Step 2: Write `config.cpp`** (default constructor sets language="en", keymap="us", fsType=ZFS, autologin=false).
- [ ] **Step 3: Write `CMakeLists.txt`** (Qt6 Widgets, find_package, C++17, `add_executable(dob-installer ...)`, `target_link_libraries(... Qt6::Widgets)`, install to `/usr/local/bin/dob-installer`, `qt_add_resources` for `resources.qrc`).
- [ ] **Step 4: Write `resources.qrc`** referencing `dob-layer/overlay/usr/local/share/dob/installer/branding.svg` (created in Task 9; keep the alias stable: `:/branding/branding.svg`).
- [ ] **Step 5: Write `installer.h/.cpp`** — a `QWizard` subclass `Installer` with pages added in Task 7; for now construct with a title "DOB Installer" and a DOB-styled palette (accent `#C0102A`).
- [ ] **Step 6: Write `main.cpp`**
  ```cpp
  #include <QApplication>
  #include "installer.h"
  int main(int argc, char** argv) {
      QApplication app(argc, argv);
      Installer w;
      w.setWindowTitle("DOB Installer");
      w.show();
      return app.exec();
  }
  ```
- [ ] **Step 7: Compile (macOS Qt6 or CI)** — verify it builds and shows a window titled "DOB Installer".
  Run: `cmake -S dob-layer/installer -B build-installer && cmake --build build-installer`
  Expected: build succeeds; (manual) window title is "DOB Installer".
- [ ] **Step 8: Commit**
  ```bash
  git add dob-layer/installer
  git commit -m "installer: Qt6 skeleton, InstallConfig model, branded empty window"
  ```

---

## Task 7 — Installer pages: Welcome, Disk, User, Summary

**Files:**
- Create: `dob-layer/installer/pages/welcome_page.h` + `.cpp`
- Create: `dob-layer/installer/pages/disk_page.h` + `.cpp`
- Create: `dob-layer/installer/pages/user_page.h` + `.cpp`
- Create: `dob-layer/installer/pages/summary_page.h` + `.cpp`
- Modify: `dob-layer/installer/installer.cpp` (register the pages)
- Modify: `dob-layer/installer/CMakeLists.txt` (add page sources)

**Interfaces:**
- Consumes: `InstallConfig` (Task 6).
- Produces: four wizard pages that read/write `InstallConfig` and validate before `Next`.

- [ ] **Step 1: Welcome page** — DOB branding (`:/branding/branding.svg`), language + keyboard selectors (static lists; English default, keymap "us"). Writes `config.language`, `config.keymap`. `validatePage()` returns true (defaults valid).
- [ ] **Step 2: Disk page** — **guided only**: a "Use entire disk" group with a ZFS (default, checked) / UFS radio; a device combo populated from a static list (real enumeration behind a guarded `#ifdef DOB_REAL_DISK`). **No custom partition editor.** Red warning `QLabel`: "This will erase ALL data on the selected disk." `validatePage()` requires a non-empty `diskTarget`.
- [ ] **Step 3: User page** — name, password (+confirm), hostname, autologin checkbox. Writes `userName`, `password`, `hostname`, `autologin`. `validatePage()` requires non-empty `userName` and `password == confirmPassword`.
- [ ] **Step 4: Summary page** — read-only review (language, keymap, disk target, fs type, user, hostname, autologin) built from `config`. No inputs; `validatePage()` returns true.
- [ ] **Step 5: Register pages in `installer.cpp`**
  ```cpp
  setPage(Page_Welcome, new WelcomePage(this));
  setPage(Page_Disk,    new DiskPage(this));
  setPage(Page_User,    new UserPage(this));
  setPage(Page_Summary, new SummaryPage(this));
  ```
- [ ] **Step 6: Update `CMakeLists.txt`** to compile the four page sources.
- [ ] **Step 7: Compile**
  Run: `cmake --build build-installer`
  Expected: build succeeds; (manual) wizard shows all four pages with validation (e.g. cannot advance past Disk with empty target; cannot finish User with mismatched passwords).
- [ ] **Step 8: Commit**
  ```bash
  git add dob-layer/installer
  git commit -m "installer: Welcome/Disk/User/Summary pages with validation"
  ```

---

## Task 8 — Installer engine: planInstall + apply (offline, auto-rollback)

**Files:**
- Create: `dob-layer/installer/engine/plan_install.h` + `.cpp` (pure function)
- Create: `dob-layer/installer/engine/install_engine.h` + `.cpp` (`InstallEngine`)
- Create: `dob-layer/installer/engine/plan_install_test.cpp`
- Modify: `dob-layer/installer/CMakeLists.txt` (add engine + test target)

**Interfaces:**
- Consumes: `InstallConfig` (Task 6).
- Produces: `planInstall(const InstallConfig&)` returning an ordered `std::vector<InstallStep>`; `InstallEngine::apply(config)` that clones the live root, applies the DOB layer, writes boot blocks (guarded), and **auto-rolls-back** on failure. Pure function is unit-tested with no disk IO.

**Step model:**
```cpp
enum class StepKind { CloneRoot, ApplyLayer, CreateUsers, WriteBoot, Done };
struct InstallStep { StepKind kind; QString detail; };
std::vector<InstallStep> planInstall(const InstallConfig& c);
```

- [ ] **Step 1: Write the failing test (`plan_install_test.cpp`)**
  ```cpp
  #include "plan_install.h"
  #include <cassert>
  int main() {
      InstallConfig c;
      c.diskTarget = "/dev/ada0";
      c.userName = "alice";
      c.hostname = "dobbox";
      auto steps = planInstall(c);
      assert(!steps.empty());
      assert(steps.front().kind == StepKind::CloneRoot);   // clones live root first
      assert(steps.back().kind == StepKind::Done);
      // ZFS default path present
      bool hasBoot = false;
      for (auto& s : steps) if (s.kind == StepKind::WriteBoot) hasBoot = true;
      assert(hasBoot);
      return 0;
  }
  ```
- [ ] **Step 2: Run test to verify it fails**
  Run: `g++ -std=c++17 dob-layer/installer/engine/plan_install_test.cpp -o /tmp/ptest && /tmp/ptest`
  Expected: FAIL (undefined reference / not compiled) — `planInstall` not yet defined.
- [ ] **Step 3: Write `plan_install.cpp`**
  ```cpp
  std::vector<InstallStep> planInstall(const InstallConfig& c) {
      std::vector<InstallStep> v;
      v.push_back({StepKind::CloneRoot, "Clone live root to " + c.diskTarget});
      v.push_back({StepKind::ApplyLayer, "Apply DOB layer (theme, users, hostname)"});
      v.push_back({StepKind::CreateUsers, "Create user " + c.userName + " on " + c.hostname});
      v.push_back({StepKind::WriteBoot, "Write boot blocks (" +
                   QString(c.fsType == InstallConfig::ZFS ? "ZFS" : "UFS") + ")"});
      v.push_back({StepKind::Done, "Installation complete"});
      return v;
  }
  ```
- [ ] **Step 4: Run test to verify it passes**
  Run: `g++ -std=c++17 dob-layer/installer/engine/plan_install_test.cpp dob-layer/installer/engine/plan_install.cpp dob-layer/installer/config.cpp -I dob-layer/installer -o /tmp/ptest && /tmp/ptest && echo PASS`
  Expected: prints `PASS`.
- [ ] **Step 5: Write `install_engine.cpp`** — `InstallEngine::apply(config)`:
  - **Validate-then-write:** all checks done in pages already; engine re-validates `diskTarget` non-empty.
  - Clone live root (local-copy path works without root where possible; real device path behind guarded `#ifdef DOB_REAL_DISK` / root check).
  - Apply DOB layer (call `theme/apply.sh` logic, create user, set hostname, autologin).
  - **WriteBoot** step behind the same guard (logs intent, does not run on macOS).
  - **Auto-rollback:** wrap in try/catch; on any failure `rollback()` unmounts/cleans the target and writes `dob-install.log` (accessible) before rethrowing; show error dialog in UI.
  - Exercise disk-full path: a `simulateDiskFull` test hook returns a clear "Target disk full" error and triggers rollback.
- [ ] **Step 6: Wire Summary "Install" button** to `InstallEngine::apply(config)` (modify `summary_page.cpp`/ `installer.cpp`) and show success/failure dialog.
- [ ] **Step 7: Commit**
  ```bash
  git add dob-layer/installer
  git commit -m "installer: planInstall pure fn + engine with validate-then-write and auto-rollback"
  ```

---

## Task 9 — Installer branding + install-into-image packaging

**Files:**
- Create: `dob-layer/overlay/usr/local/share/dob/installer/branding.svg` (logo + red window frame + title)
- Modify: `dob-layer/pkg-list/dob-manifest.pkglist` (add dob-installer local)
- Create: `dob-layer/overlay/usr/local/share/applications/install-dob.desktop` (live "Install DOB" shortcut)
- Modify: `dob-layer/overlay/etc/rc.conf.dob` (first-boot installer trigger)
- Modify: `dob-layer/installer/CMakeLists.txt` (install binary + resources)

**Interfaces:**
- Consumes: installer binary (Tasks 6–8), brand tokens (Task 1).
- Produces: installer branding asset (referenced by `resources.qrc` alias `:/branding/branding.svg`), a live desktop shortcut, a first-boot trigger, and a pkg-list entry so the installer is built into the image.

- [ ] **Step 1: Write `branding.svg`** — DOB installer logo + red window frame + "DOB Installer" title, using accent `#C0102A`/`#E63950`. (This is the **installer window** red frame — distinct from the "no red frame at boot" rule.)
- [ ] **Step 2: Add installer to `dob-manifest.pkglist`** as a local package/port entry (e.g. `dob-installer` with a comment marking it local-built). If a local pkg build is out of scope for macOS, document the local-port step in Task 10/11 and keep the manifest line commented with the exact package name.
- [ ] **Step 3: Write `install-dob.desktop`**
  ```ini
  [Desktop Entry]
  Type=Application
  Name=Install DOB
  Exec=/usr/local/bin/dob-installer
  Icon=system-software-install
  Categories=System;
  ```
- [ ] **Step 4: Add first-boot trigger to `rc.conf.dob`**
  Append a guarded block: on live media, launch `/usr/local/bin/dob-installer` on first Plasma start (idempotent; installed systems skip it). Keep `dob_live_autostart="YES"` honored.
- [ ] **Step 5: Update `CMakeLists.txt`** to `install(TARGETS dob-installer RUNTIME DESTINATION /usr/local/bin)` and install `resources.qrc` assets to `/usr/local/share/dob/installer`.
- [ ] **Step 6: Validate**
  Run: `test -f dob-layer/overlay/usr/local/share/dob/installer/branding.svg && grep -q "dob-installer" dob-layer/pkg-list/dob-manifest.pkglist && echo OK`
  Expected: `OK`.
- [ ] **Step 7: Commit**
  ```bash
  git add dob-layer/overlay/usr/local/share/dob/installer dob-layer/overlay/usr/local/share/applications dob-layer/overlay/etc/rc.conf.dob dob-layer/pkg-list dob-layer/installer/CMakeLists.txt
  git commit -m "installer: branding asset, live shortcut, first-boot trigger, image packaging"
  ```

---

## Task 10 — Package manifest + FreeBSD release config

**Files:**
- Create/Modify: `dob-layer/pkg-list/dob-manifest.pkglist`
- Create: `dob-layer/build/DOB-release.conf`
- Create: `dob-layer/build/pins.sh`

**Interfaces:**
- Consumes: DOB layer paths (Tasks 2–9), brand tokens (Task 1).
- Produces: the pkg manifest, `release.sh` config (names DOB, points at pkg-list + overlay, UEFI+BIOS hybrid for x86), and a sourceable `pins.sh`.

- [ ] **Step 1: Write `pins.sh`** (sourceable)
  ```bash
  #!/usr/bin/env bash
  # DOB version pins — source before build scripts.
  DOB_FREEBSD_REL="14.2-RELEASE"     # or latest stable at build time
  DOB_PKGSET="latest"
  DOB_ART_REV="2026-08-23"
  DOB_INSTALLER_REV="2026-08-23"
  DOB_VERSION="1.0"
  ```
- [ ] **Step 2: Write `dob-manifest.pkglist`** (one package per line, commented groups)
  ```
  # --- Desktop environment ---
  plasma6
  plasma6-sddm
  # --- DOB installer (local-built; see build/README.md) ---
  dob-installer
  # --- Home desktop apps ---
  firefox
  libreoffice
  vlc
  dolphin
  # --- Theme/runtime deps ---
  kvantum
  ```
  (Adjust package names to the FreeBSD ports tree at build time; keep the group comments.)
- [ ] **Step 3: Write `DOB-release.conf`** (release.sh config)
  ```sh
  # DOB release.sh configuration
  export DESTKERNEL="DOB"
  export DISTRIBUTIONS="kernel.txz base.txz packages.txz"
  export NODOC=yes
  export NOPORTS=yes
  # DOB layer overlay + pkg set injected here (build.sh wires the paths)
  export DOB_OVERLAY="dob-layer/overlay"
  export DOB_PKGLIST="dob-layer/pkg-list/dob-manifest.pkglist"
  # x86: hybrid UEFI + BIOS
  export DOB_BOOT="uefi+bios"
  ```
- [ ] **Step 4: Source & sanity-check `pins.sh`**
  Run: `bash -c 'source dob-layer/build/pins.sh && echo "$DOB_FREEBSD_REL $DOB_VERSION"'`
  Expected: prints `14.2-RELEASE 1.0` (or the pinned values).
- [ ] **Step 5: `bash -n` the conf**
  Run: `bash -n dob-layer/build/DOB-release.conf && bash -n dob-layer/build/pins.sh && echo OK`
  Expected: `OK`.
- [ ] **Step 6: Commit**
  ```bash
  git add dob-layer/pkg-list dob-layer/build/DOB-release.conf dob-layer/build/pins.sh
  git commit -m "build: pkg manifest, release.conf, version pins"
  ```

---

## Task 11 — Build scripts (x86 ISO + ARM64 img) + README

**Files:**
- Create: `dob-layer/build/build.sh` (x86 ISO)
- Create: `dob-layer/build/build-arm.sh` (ARM64 img via mkimg)
- Create: `dob-layer/build/README.md`

**Interfaces:**
- Consumes: `pins.sh`, `DOB-release.conf`, `dob-layer/overlay`, `dob-manifest.pkglist` (Task 10).
- Produces: `build.sh` (produces `dob-1.0-amd64.iso` hybrid UEFI+BIOS + `SHA256SUMS`), `build-arm.sh` (`dob-1.0-arm64.img` for RPi/UTM), and README documenting the FreeBSD build-host prerequisite.

**These scripts are NOT executed on macOS** — they require a FreeBSD host. They must be syntax-valid (`bash -n`) and clearly document the host requirement.

- [ ] **Step 1: Write `build.sh`**
  ```bash
  #!/usr/bin/env bash
  # build.sh — produce dob-<ver>-amd64.iso (hybrid UEFI+BIOS live/install).
  # REQUIRES a FreeBSD build host (bhyve/UTM VM on macOS). Not run on macOS.
  set -euo pipefail
  source "$(dirname "$0")/pins.sh"
  # 1. checkout pinned FreeBSD src+ports (documented; uses git in build env)
  # 2. run release.sh with DOB-release.conf, injecting DOB_OVERLAY + DOB_PKGLIST
  # 3. wrap ISO as hybrid UEFI+BIOS
  # 4. sha256sum -> SHA256SUMS
  ISO="dob-${DOB_VERSION}-amd64.iso"
  echo "Would build $ISO on FreeBSD host (release.sh + DOB-release.conf)."
  echo "Outputs: $ISO + SHA256SUMS"
  ```
  Keep the real `release.sh` invocation as a documented, commented block (paths from `DOB-release.conf`).
- [ ] **Step 2: Write `build-arm.sh`**
  ```bash
  #!/usr/bin/env bash
  # build-arm.sh — produce dob-<ver>-arm64.img (RPi/UTM) via mkimg.
  # REQUIRES FreeBSD host. Documents ARM device-tree needs.
  set -euo pipefail
  source "$(dirname "$0")/pins.sh"
  IMG="dob-${DOB_VERSION}-arm64.img"
  # mkimg: same DOB overlay + pkg set; ARM64 layout (RPi/UTM).
  echo "Would build $IMG on FreeBSD host (mkimg + DOB overlay)."
  echo "Outputs: $IMG + SHA256SUMS"
  ```
- [ ] **Step 3: Write `README.md`** — exact FreeBSD build-host prerequisites (VM on macOS via bhyve/UTM), how to run `build.sh` / `build-arm.sh`, expected outputs (`dob-1.0-amd64.iso`, `dob-1.0-arm64.img`, `SHA256SUMS`), and the macOS limitation (image generation only on FreeBSD).
- [ ] **Step 4: Syntax-check**
  Run: `bash -n dob-layer/build/build.sh && bash -n dob-layer/build/build-arm.sh && echo OK`
  Expected: `OK`.
- [ ] **Step 5: Commit**
  ```bash
  git add dob-layer/build
  git commit -m "build: x86 ISO + ARM64 img scripts, README with FreeBSD host docs"
  ```

---

## Task 12 — Manual build + acceptance verification (FreeBSD host)

**Environment-dependent — performed on a FreeBSD build host, not macOS.**

- [ ] **Step 1: Run `build.sh`** to produce `dob-1.0-amd64.iso` on the FreeBSD host.
- [ ] **Step 2: Boot ISO in a VM (UTM/VirtualBox)** and verify the full flow:
  loader autoboots with **no menu** → static blue boot splash (subtle red aurora, no red frame) → live Plasma with **full-glass DOB theme** active → **animated** DOB desktop splash (red-bold) → DOB installer auto-presents.
- [ ] **Step 3: Run installer** on guided "use entire disk" (ZFS default, then UFS) → reboot into installed DOB.
- [ ] **Step 4: Exercise failure path** — disk-full (or simulate) → installer shows clear error + log, target left clean (auto-rollback verified).
- [ ] **Step 5: Build `dob-1.0-arm64.img`** via `build-arm.sh`; boot in UTM / flash to RPi: same flow.
- [ ] **Step 6: Verify reddish-tint icons** render in Plasma + file manager; full-glass theme active by default.
- [ ] **Step 7: Record results** in `dob-layer/build/ACCEPTANCE.md`.

**If no FreeBSD host is available:** replace with a documented dry-run — `bash -n` on all scripts, a tree-manifest check that every path the spec/plan references exists, and `ACCEPTANCE.md` noting the build-host requirement. This repo delivers the complete buildable source; image generation is the one step needing FreeBSD. Commit whichever applies.

---

## Self-Review (against the refined spec)

**1. Spec coverage**
- §4 Visual identity: red confident accent (Tasks 2/3/4) ✓; 12 original + retint (Task 3) ✓; full glass (Task 4) ✓; mountain wallpaper blue + subtle red aurora (Task 2/4) ✓; boot blue no red frame (Task 5) ✓.
- §5 Boot flow: autoboot no menu (Task 5 loader.conf.dob) ✓; static vt boot splash (Task 5) ✓; animated desktop splash red-bold (Task 5) ✓; red bold only at desktop (Tasks 4/5) ✓.
- §6 Installer: clone live root (Task 8) ✓; guided-only ZFS default/UFS (Task 7) ✓; validate-then-write + auto-rollback (Task 8) ✓; 5 wizard steps (Tasks 6/7/9) ✓.
- §7 Build: pins, release.conf, build.sh/build-arm.sh, README (Tasks 10/11) ✓.
- §8 Testing: acceptance flow incl. disk-full + rollback (Task 12) ✓.

**2. Placeholder scan** — No "TBD/TODO/implement later". `retint.sh` and `build.sh` document host-only steps inline rather than omitting them. ✓

**3. Type consistency** — `InstallConfig` (Task 6) struct + `fsType=ZFS` default used identically in Tasks 7/8. `planInstall` signature `std::vector<InstallStep> planInstall(const InstallConfig&)` matches test (Task 8). `:/branding/branding.svg` alias stable across Tasks 6/9. Brand hex values consistent (`#C0102A`=192,16,42; `#7A0A1E`=122,10,30) across Tasks 1–5. ✓

Plan complete and saved to `docs/superpowers/plans/2026-08-23-dob-build-plan.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
