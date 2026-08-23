# DOB splash assets

## Boot splash (static)
- `boot-splash-1920x1080.png`
- `boot-splash-1366x768.png`

These are **placeholder PNGs** committed by Task 5. The build host (where a
real SVG rasterizer such as `rsvg-convert` is available) overwrites them with
true rasterizations of `../art/boot-splash.svg` (blue field + subtle red
aurora, **no red frame**, per the DOB refinement rules). The placeholders are
valid PNGs at exactly 1920x1080 and 1366x768 with a blue gradient base and a
small red accent bar, so the dimensions and format are correct for the `vt`
static splash path.

To regenerate on a host with `rsvg-convert`:
```bash
rsvg-convert -w 1920 -h 1080 ../art/boot-splash.svg -o boot-splash-1920x1080.png
rsvg-convert -w 1366 -h 768  ../art/boot-splash.svg -o boot-splash-1366x768.png
```

## Desktop splash (animated, red-bold)
- `desktop-splash/` — a self-contained Plasma splash package.
  - `metadata.desktop` — `Type=Plasma/Splash`, `Name=DOB`.
  - `contents/components/Main.qml` — QtQuick splash showing the red-bold
    `DOB` wordmark on a blue glass field with an animated bold-red accent
    sweep. This is where red goes bold; the boot splash stays blue.

The boot loader (`loader.conf.dob`) autoboots with zero delay and no menu.
