# DOB Build Acceptance Verification (Dry-Run)

**Date:** 2026-08-23  
**Environment:** macOS (no FreeBSD build host available)  
**Fallback:** Documented dry-run per build plan Task 12 specification

---

## 1. Bash Syntax Validation (`bash -n`)

All build scripts and configuration files pass syntax check:

| File | Result |
|------|--------|
| `dob-layer/build/build.sh` | PASS |
| `dob-layer/build/build-arm.sh` | PASS |
| `dob-layer/build/pins.sh` | PASS |
| `dob-layer/build/DOB-release.conf` | PASS |
| `dob-layer/overlay/etc/loader.conf.dob` | PASS |
| `dob-layer/overlay/etc/rc.conf.dob` | PASS |

---

## 2. Tree-Manifest Check (All Referenced Paths Exist)

Every path referenced in the spec/plan has been verified present in the repository:

### Overlay — Brand & Configuration
- `dob-layer/overlay/etc/dob.conf` ✅

### Overlay — Art Assets (Task 2)
- `dob-layer/overlay/usr/local/share/dob/art/logo.svg` ✅
- `dob-layer/overlay/usr/local/share/dob/art/wallpaper.svg` ✅
- `dob-layer/overlay/usr/local/share/dob/art/boot-splash.svg` ✅
- `dob-layer/overlay/usr/local/share/dob/art/desktop-splash.svg` ✅
- `dob-layer/overlay/usr/local/share/dob/art/key-icons/*.svg` (12 files) ✅

### Overlay — Splash Assets (Task 5)
- `dob-layer/overlay/usr/local/share/dob/splash/boot-splash-1920x1080.png` ✅
- `dob-layer/overlay/usr/local/share/dob/splash/boot-splash-1366x768.png` ✅
- `dob-layer/overlay/usr/local/share/dob/splash/desktop-splash/` (dir with `metadata.desktop` + `Main.qml`) ✅

### Overlay — Icon Theme (Task 3)
- `dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/index.theme` ✅
- `dob-layer/overlay/usr/local/share/dob/icons/DOB-Red/apps/` (12 source + symlinks) ✅
- `dob-layer/overlay/usr/local/share/dob/icons/retint.sh` ✅
- `dob-layer/overlay/usr/local/share/dob/icons/sample/` (26 files) ✅

### Overlay — Theme (Task 4)
- `dob-layer/overlay/usr/local/share/dob/theme/lookandfeel/DOB/metadata.desktop` ✅
- `dob-layer/overlay/usr/local/share/dob/theme/lookandfeel/DOB/colors` ✅
- `dob-layer/overlay/usr/local/share/dob/theme/kvantum/DOB-Red.kvconfig` ✅
- `dob-layer/overlay/usr/local/share/dob/theme/wallpaper/mountain.png` ✅
- `dob-layer/overlay/usr/local/share/dob/theme/apply.sh` ✅
- `dob-layer/overlay/usr/local/share/dob/theme/skel/.config/kdeglobals` ✅
- `dob-layer/overlay/usr/local/share/dob/theme/skel/.config/Kvantum/kvantum.kvconfig` ✅

### Overlay — Installer Branding & Desktop Entry (Task 9)
- `dob-layer/overlay/usr/local/share/dob/installer/branding.svg` ✅
- `dob-layer/overlay/usr/local/share/applications/install-dob.desktop` ✅

### Overlay — Boot Config (Task 5)
- `dob-layer/overlay/etc/loader.conf.dob` ✅
- `dob-layer/overlay/etc/rc.conf.dob` ✅

### Package & Build Config (Tasks 10, 11)
- `dob-layer/pkg-list/dob-manifest.pkglist` ✅
- `dob-layer/build/DOB-release.conf` ✅
- `dob-layer/build/pins.sh` ✅
- `dob-layer/build/build.sh` ✅
- `dob-layer/build/build-arm.sh` ✅

### Installer Source (Tasks 6–9)
- `dob-layer/installer/CMakeLists.txt` ✅
- `dob-layer/installer/config.cpp` ✅
- `dob-layer/installer/config.h` ✅
- `dob-layer/installer/installer.cpp` ✅
- `dob-layer/installer/installer.h` ✅
- `dob-layer/installer/main.cpp` ✅
- `dob-layer/installer/engine/plan_install.h` ✅
- `dob-layer/installer/engine/plan_install.cpp` ✅
- `dob-layer/installer/engine/plan_install_test.cpp` ✅
- `dob-layer/installer/engine/install_engine.h` ✅
- `dob-layer/installer/engine/install_engine.cpp` ✅
- `dob-layer/installer/pages/welcome_page.h` ✅
- `dob-layer/installer/pages/welcome_page.cpp` ✅
- `dob-layer/installer/pages/user_page.h` ✅
- `dob-layer/installer/pages/user_page.cpp` ✅
- `dob-layer/installer/pages/disk_page.h` ✅
- `dob-layer/installer/pages/disk_page.cpp` ✅
- `dob-layer/installer/pages/summary_page.h` ✅
- `dob-layer/installer/pages/summary_page.cpp` ✅
- `dob-layer/installer/resources.qrc` ✅

---

## 3. Build-Host Requirement

**Full acceptance (boot, VM smoke test, installer end-to-end) requires a FreeBSD 14.2-RELEASE build host.**

Per the plan (Task 12), this dry-run is the documented fallback when no FreeBSD host is available. The following items are **not** validated in this dry-run and require a FreeBSD build host:

- ISO image generation (`build.sh` execution with `make release`)
- ARM64 image generation (`build-arm.sh` execution with `mkimg`)
- BIOS + UEFI boot verification (VM or hardware)
- Installer execution (Calamares + DOB modules)
- First-boot Plasma desktop launch with DOB theme
- Splash screen display (boot + desktop)
- Package installation verification (all ports from `dob-manifest.pkglist`)

---

## 4. Summary

| Check | Status |
|-------|--------|
| `bash -n` on all scripts | ✅ ALL PASS |
| Tree-manifest (all paths) | ✅ ALL PRESENT |
| FreeBSD host available | ❌ NO — dry-run only |

**Conclusion:** The repository is structurally complete and syntactically valid. Full acceptance testing is blocked on FreeBSD build host availability per the plan specification.