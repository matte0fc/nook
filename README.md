# Nook

**A native macOS utility that turns the MacBook notch into a quiet, useful surface.**

Nook replaces the system volume and brightness pop-ups with a minimal indicator that
grows out of the notch, shows the level, and tucks back in. No window, no dock icon,
no settings to learn.

<p align="center">
  <img src="docs/images/hud-volume.png" width="440" alt="Nook showing the volume level below the MacBook notch">
</p>

<p align="center">
  <img src="docs/images/hud-brightness.png" width="290" alt="Brightness indicator">
  &nbsp;
  <img src="docs/images/hud-muted.png" width="290" alt="Muted state">
</p>

> The images above are rendered by the app's own SwiftUI view (`Nook --render-previews`),
> not mock-ups.

---

## Highlights

- **Notch-native design.** The indicator is pure black, exactly as wide as the notch and
  extends only downward, so it reads as part of the hardware. Icon and bar are slightly
  dimmed to limit backlight bloom around them.
- **Replaces the system HUD.** Volume and brightness keys are handled by Nook, so the
  default macOS overlay no longer covers the middle of the screen.
- **Follows every change.** It also appears when volume changes from Control Center,
  AirPods or another app, and when brightness is adjusted with the Control Center slider.
- **Familiar controls.** Standard 1/16 steps, with <kbd>Shift</kbd>+<kbd>Option</kbd> for
  fine 1/64 steps, as in macOS.
- **Graceful fallback.** Outputs macOS cannot control (e.g. HDMI audio) and external-only
  setups are left to the system. Macs without a notch get the same indicator at the top of
  the screen.
- **Private by design.** No network access, no analytics, no data stored.

## How it works

| Component | Responsibility |
| --- | --- |
| `NotchPanel` | Borderless, click-through `NSPanel` above the menu bar, positioned from the screen's `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` so it lines up with the notch on any MacBook. |
| `NotchView` | SwiftUI view. Always exactly notch-wide; only its height animates, so the indicator slides straight down out of the notch with the icon and bar riding on its bottom edge. |
| `MediaKeyTap` | A `CGEventTap` that intercepts the volume and brightness keys before macOS handles them, which is what hides the system HUD. |
| `VolumeController` | CoreAudio: reads and sets the default output device's volume and mute state, and listens for changes and device switches. |
| `Brightness` | Built-in display brightness through the DisplayServices framework, loaded at runtime. |
| `HUDModel` | Shared observable state and the auto-collapse timer. |

## Download

1. Download **Nook.zip** from the [latest release](https://github.com/matte0fc/nook/releases/latest)
   and unzip it.
2. Move **Nook.app** to your Applications folder and open it.
3. Nook isn't notarized by Apple, so macOS blocks it the first time. Go to
   **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
4. Allow Nook under **System Settings → Privacy & Security → Accessibility**.
   This is needed to take over the volume and brightness keys.

Requires an Apple Silicon Mac (every MacBook with a notch is one) on macOS 14 or later.

## Build from source

Requires Swift 5.10+ (Xcode or just the Command Line Tools).

```bash
git clone https://github.com/matte0fc/nook.git
cd nook
./build.sh --install
```

`build.sh` compiles a release build, wraps it in `Nook.app`, signs it ad hoc and, with
`--install`, copies it to `~/Applications` and launches it.

On first launch, allow Nook under **System Settings → Privacy & Security → Accessibility**.
The permission is needed to intercept the volume and brightness keys. Until it's granted,
Nook still shows its indicator but macOS also shows its own.

The menu bar icon offers **Preview Volume HUD**, **Launch at Login** and **Quit**.

## Project structure

```
Sources/Nook/
├── main.swift             App entry point
├── AppDelegate.swift      Window placement, key handling, menu bar item
├── NotchView.swift        The indicator and the NotchShape
├── HUDModel.swift         Shared state and timing
├── MediaKeyTap.swift      Volume and brightness key interception
├── VolumeController.swift CoreAudio volume and mute
├── Brightness.swift       Display brightness
└── PreviewRenderer.swift  Renders the README images
Resources/Info.plist       Menu-bar-only app (LSUIElement)
build.sh                   Build, bundle, sign, install
```

## Design decisions

- **The notch has no pixels.** Anything drawn "inside" it is invisible, so the indicator
  extends a short strip below the notch. A version that grew sideways at exactly notch
  height was built and tested; the compact drop-down read more clearly and was kept.
- **No numbers.** A bar and an SF Symbol carry the information; a percentage added noise.
- **Down, not out.** The indicator never grows sideways or scales from its centre; it
  drops straight down like an elevator, so it reads as the notch extending rather than
  something appearing from behind it.
- **Invisible when idle.** Collapsed, it sits entirely behind the hardware cut-out and is
  hidden, so there is nothing to see until something changes.

## Known limitations

- Brightness uses Apple's private DisplayServices framework, so a future macOS release
  could change it.
- macOS ties the Accessibility permission to the app's signature. `build.sh` signs with a
  local certificate named **Nook Local Signing** if one is in your keychain, which keeps the
  permission across rebuilds; otherwise it signs ad hoc and the permission has to be granted
  again after each build.

## Process

Nook was designed and directed by me and built with Claude Code as the engineering
partner. The product direction, iteration by iteration, is in the
[development log](docs/DEVELOPMENT_LOG.md). Giving the same direction to Claude Code
should get you something very close.

Inspired by [Alcove](https://tryalcove.com). Not affiliated.

## License

[MIT](LICENSE) © 2026 Mattias Andersson
