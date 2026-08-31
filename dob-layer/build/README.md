# DOB Build Scripts — FreeBSD Host Required

> **These scripts do not run on macOS.** They must be executed on a FreeBSD host (bare metal or VM).

---

## Prerequisites

### FreeBSD Build Host

- **FreeBSD 14.2-RELEASE** (or the version pinned in `pins.sh` as `DOB_FREEBSD_REL`)
- Root access (for `release.sh`, `mkimg`, and package installation)
- Sufficient disk space (~30 GB for source, build objects, and output images)
- Internet access (to fetch FreeBSD src/ports and packages)

### On macOS: Run FreeBSD in a VM

| Option | Notes |
|--------|-------|
| **UTM** (recommended) | Apple Silicon native; runs FreeBSD arm64 VM. Easy GUI, virtio support. |
| **bhyve** (via `vm-bhyve` on FreeBSD host) | Not directly on macOS; requires a FreeBSD host first. |
| **VirtualBox / VMware** | Works on Intel macOS; slower on Apple Silicon (emulation). |

**Recommended path for macOS users:**
1. Install **UTM** from the Mac App Store or <https://mac.getutm.app/>
2. Create a new VM → **FreeBSD** → **arm64 (aarch64)** → download FreeBSD 14.2-RELEASE arm64 ISO
3. Allocate ≥ 8 GB RAM, ≥ 4 vCPUs, ≥ 60 GB disk
4. Install FreeBSD inside the VM (select `root` / `da0`, default partitioning)
5. Post-install: `pkg install -y git ca_root_nss` (for HTTPS git clones)
6. Clone this repository inside the VM and run the build scripts.

---

## Files in This Directory

| File | Purpose |
|------|---------|
| `pins.sh` | Version pins (FreeBSD release, package set, DOB version) |
| `DOB-release.conf` | `release.sh` configuration (distributions, overlay, pkg list, boot mode) |
| `dob-src.conf` | `src.conf` that skips in-tree LLVM/Clang/LLD/Binutils builds; host toolchain used instead |
| `build.sh` | x86_64 hybrid UEFI+BIOS ISO build (sourced documentation) |
| `build-arm.sh` | ARM64 (RPi/UTM) disk image build via `mkimg` (sourced documentation) |

---

## LLVM Handling

LLVM is **not built in-tree** during `buildworld`. Both `build.sh` and `build-arm.sh` pass `dob-src.conf` as `SRCCONF`, which sets `WITHOUT_LLVM/CLANG/LLD/BINUTILS=YES`. The host toolchain (`XCC/XCXX/XCPP/XLD`) is used instead.

LLVM and its dependents (`llvm18`, `libclc`, `mesa-dri`, `qt6-*`) are installed as **pre-built packages** from the FreeBSD package repository during image creation, via `dob-manifest.pkglist`. This keeps build times down and avoids compiling LLVM from source.

## How to Build

### Inside the FreeBSD VM (as root):

```sh
# 1. Prepare src/ports at pinned release
git clone --branch "releng/14.2-RELEASE" --depth 1 https://git.FreeBSD.org/src.git /usr/src
git clone --branch "releng/14.2-RELEASE" --depth 1 https://git.FreeBSD.org/ports.git /usr/ports

# 2. Build x86_64 ISO
cd /path/to/dob-layer/build
./build.sh   # This script documents the steps; the real invocation is commented inside.
# Real command (run manually after reviewing build.sh):
# cd /usr/src/release && env DOB_OVERLAY="dob-layer/overlay" DOB_PKGLIST="dob-layer/pkg-list/dob-manifest.pkglist" DOB_VERSION="1.0" sh release.sh -c ../DOB-release.conf amd64

# 3. Build ARM64 image
./build-arm.sh   # Documents mkimg steps; real commands commented inside.
```

> **Note:** The scripts as committed are *documentation-only* (they `echo` what would happen). Uncomment and adapt the real commands inside each script when running on the FreeBSD host.

---

## Expected Outputs

After successful builds on the FreeBSD host, you will have:

| Output | Description |
|--------|-------------|
| `dob-1.0-amd64.iso` | Hybrid UEFI + BIOS bootable ISO (live/install) for x86_64 |
| `dob-1.0-arm64.img` | GPT disk image with EFI + UFS root for RPi 4/5 or UTM ARM64 VM |
| `SHA256SUMS` | SHA-256 checksums for both artifacts |

---

## macOS Limitation

**Image generation (ISO / IMG) only works on FreeBSD.** The tooling (`release.sh`, `mkimg`, `make buildworld`, `pkg` with FreeBSD repositories) is FreeBSD-specific. macOS cannot produce FreeBSD bootable images.

**Workaround:** Use UTM to run a FreeBSD ARM64 VM on macOS (Apple Silicon) or a FreeBSD x86_64 VM (Intel macOS / emulated on Apple Silicon). The VM *is* the build host.

---

## Verification

Syntax-check the scripts (works on any `bash`):

```sh
bash -n dob-layer/build/build.sh && bash -n dob-layer/build/build-arm.sh && echo OK
# Expected output: OK
```

---

## References

- FreeBSD `release.sh`: <https://man.freebsd.org/cgi/man.cgi?query=release&sektion=8>
- FreeBSD `mkimg`: <https://man.freebsd.org/cgi/man.cgi?query=mkimg&sektion=1>
- UTM: <https://mac.getutm.app/>
- FreeBSD arm64 on RPi: <https://wiki.freebsd.org/FreeBSD/arm64/RaspberryPi>