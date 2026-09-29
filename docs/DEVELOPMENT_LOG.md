# Development log

Nook was built in one working session, with me directing product and design and
Claude Code (Anthropic) writing and building the code. Each entry below gives the
direction I gave, what was delivered, and the decision that followed.

The direction is edited for clarity; the substance and order are unchanged.

---

## 1. Brief

> Build a native macOS utility, in the spirit of Alcove, that makes the MacBook notch
> useful. The first capability is volume: when the level changes, an indicator should
> emerge from the notch. The aesthetic is the priority. It has to look clean and feel
> like part of the hardware.

**Delivered**
- Menu-bar-only Swift app (SwiftUI + AppKit), built with Swift Package Manager and a
  small bundling script, since the machine had no full Xcode install.
- A click-through panel aligned to the notch using the screen's safe-area geometry.
- An animatable notch-shaped indicator: speaker icon, percentage and level bar.
- Volume keys intercepted with a `CGEventTap` so the macOS HUD no longer appears;
  volume set and observed through CoreAudio.

**Decision:** direction approved. Refine the proportions.

---

## 2. Refinement

> Bring the footprint down so it sits much closer to the physical notch. Remove the
> numeric readout; the bar is enough. Extend the same treatment to display brightness.

**Delivered**
- Width reduced to the notch plus a few points; a short strip below the notch holds a
  small icon and a thin bar.
- Percentage removed.
- Brightness keys handled through the DisplayServices framework, with a sun icon
  that changes with the level.

**Decision:** move closer still to the notch's exact size.

---

## 3. Testing a constraint

> Constrain the indicator to the exact dimensions of the notch, including when a key is
> pressed, and centre the level bar vertically. Brightness changes made from Control
> Center should trigger it too.

**Finding:** the notch is a cut-out in the display with no pixels, so anything drawn
fully inside it is invisible. The closest option, an indicator at exactly notch height
that grows slightly sideways (similar to the iPhone's Dynamic Island), was built for
comparison.

**Delivered**
- The notch-height variant, for side-by-side evaluation.
- A brightness watcher, so the indicator appears for changes from any source, including
  the Control Center slider.
- Diagnostic logging for the brightness key path.

**Decision:** keep the compact drop-down from iteration 2 and centre the icon and bar
vertically in the visible strip.

---

## 4. Polish and presentation

> Make sure the native macOS HUD never appears alongside Nook's, as it doesn't with
> Alcove. Then document the project to a professional standard for my portfolio.

**Delivered**
- Traced the system HUD still appearing to macOS dropping the Accessibility permission
  each time an ad-hoc signed build changed. Nook is now signed with a stable local
  certificate, the same principle a commercial app's Developer ID relies on, so the
  permission holds across builds.
- Verified on hardware: the native volume and brightness overlays no longer appear.
- A `--render-previews` mode that renders the real SwiftUI view to PNG for the README.
- README, this log and an MIT license.

---

## 5. Fidelity to the hardware

> Match the notch's width exactly; even a few millimetres of overhang breaks the
> illusion. And push the black as deep as the display allows, since the seam between
> the physical notch and the indicator is visible.

**Finding:** the indicator was already pure black (RGB 0,0,0). The visible seam is the
display's backlight glowing around bright content, which the physical notch doesn't have.

**Delivered**
- Width locked to the notch, with no side overhang or top flares.
- Soft shadow removed; icon and bar dimmed slightly to reduce backlight bloom, which
  makes the black read deeper.

---

## 6. Motion

> The indicator currently scales out from its centre, so it looks like it's coming from
> behind the notch. It should drop straight down like an elevator, so it reads as the
> notch itself extending.

**Delivered**
- Width held constant; only the height animates.
- Icon and bar pinned to the bottom edge, riding down with it instead of fading in.
- Tighter spring on the way down, no bounce on the way up, and hidden only once fully
  retracted.

**Decision:** approved. Ship it.

---

## 7. Release

> Publish the project on GitHub so others can download the app or rebuild it, and add
> it to my portfolio.

**Delivered:** public repository, a downloadable build on the Releases page, and a
portfolio case study.

---

## What this project shows

- **Product judgement:** a clear aesthetic bar held across iterations, and quick
  decisions once options could be compared.
- **Working with constraints:** hardware limits were treated as design input rather
  than worked around badly.
- **AI-assisted delivery:** turning intent into precise direction for an AI engineering
  partner, from brief to documented release, in one session.
