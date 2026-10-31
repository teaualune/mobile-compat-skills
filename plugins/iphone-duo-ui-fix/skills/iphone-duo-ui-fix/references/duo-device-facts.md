# iPhone Duo — facts the fixes depend on

Verified 2026-10-30 against Apple's docs, Apple's "iPhone Duo Group Lab" Q&A (developer.apple.com/forums/thread/847644), Tech Talks 111461–111466, and simulator measurements by several independent developers. Apple publishes pixels, not points; point sizes below are derived (@3x) and match every hands-on measurement. If a value here disagrees with what the inventory script or the simulator reports, trust the device and update this file.

## The device in one table

| | Outer (cover) display | Inner (folding) display |
|---|---|---|
| Physical | 5.4", 1398 × 2034 px panel, 460 ppi | 7.6", 1878 × 2670 px panel, 430 ppi (rendered at 2007 × 2853 @3x, downsampled) |
| Points (@3x) | **466 × 678 pt** portrait | **951 × 669 pt** landscape (default when opened; fold runs vertically) / **669 × 951 pt** portrait (rotated; fold runs horizontally) |
| Aspect | ≈ 1.45 : 1 — wider and shorter than any other iPhone | ≈ 1.42 : 1 — nearly square; a 16:9 video gets ~134 pt of letterbox |
| Size classes | portrait: compact W / regular H; landscape: compact W / compact H | **regular W / regular H in both orientations** (like iPad), also in Split View |
| Natural orientation | portrait | **landscape (951 × 669)** — Device Hub's *Open* button gives this; the inner display *does not honour `UISupportedInterfaceOrientations`* |
| `UIUserInterfaceIdiom` | `.phone` | `.phone` (no new idiom; iPad support is not required) |
| App Store screenshots | 1398 × 2034 / 2034 × 1398 px | 2007 × 2853 / 2853 × 2007 px (required for all submissions from April 2027) |
| Model identifier | `iPhone19,4` | |

Simulator capture sizes (what the inventory script checks against): outer **1398 × 2034**, inner landscape **2853 × 2007**, inner portrait **2007 × 2853**. Outer and inner portrait have almost the same aspect ratio; only absolute size tells them apart.

### Terms and screenshot folders
The skill uses Apple's terms:

| Term | Meaning | Screenshot folder |
|---|---|---|
| **outer display** | the display you see when the device is **closed** (466 × 678 pt) | `outer/` |
| **inner display, landscape** | what you get when you **open** the device: 951 × 669 pt, wider than tall, fold runs vertically, vertical bar on the side | `inner/` (`inner_landscape/` accepted as an alias) |
| **inner display, portrait** | the open device **rotated**: 669 × 951 pt, taller than wide, fold runs horizontally, horizontal bars like a normal iPhone — rarely broken | `inner_portrait/` |
| **partially folded** | hinge between closed and flat; the fold becomes an active *division* region ("held like a book" in landscape, "in an L-shape" in portrait) | no folder; checked during validation |

Poses are **closed / open / partially folded**; hinge status in the API is `.closed`, `.partiallyOpen`, `.fullyOpen`. The fold is the **division** region, the camera/status column an **occlusion** region, the side strip the **vertical bar**. Apple does not use "cover display", "tent", "tabletop" or "crease" in developer docs. `scripts/inventory_screenshots.py` labels every file from its pixels and flags one that sits in the wrong folder.

## Insets, bars and reserved regions

- **Vertical bar.** With the iOS 27.1 SDK, toolbars and tab bars of *system* containers move into a vertical strip at the trailing edge (leading in RTL) when the device is closed and in inner-landscape / Split View. Custom bars (`UIToolbar`/`UITabBar` outside their controllers, hand-drawn Flutter bars) do not participate and stay horizontal.
- **Safe-area insets are asymmetric.** Measured on 27.1 closed: top 82, leading 0, bottom 34, **trailing 84 pt** (the status/camera rail). Inner portrait: ordinary top/bottom insets. Inner landscape and Split View: a leading *or* trailing inset. Handle each side separately; never derive horizontal padding from one side or assume left == right.
- **Reserved regions** (iOS 27.1): `ReservedRegion` in SwiftUI / `UIView.ReservedRegion` in UIKit, kinds `.division` (the fold) and `.occlusion` (cameras / Dynamic Island). The fold region is ~40 pt wide at x ≈ 455.5–495.5 of 951 and is **active only when the device is partially folded**; when flat it is reported inactive (zero width unless you ask for `.includeInactive`). Camera occlusions: outer 37 × 37 pt, inner 58 × 37 pt. Regions arrive after the first layout pass — read them in a `GeometryReader`/`layoutSubviews`, never cache.
- **Hinge** (iOS 27.1): `onHingeChange` / `DeviceHinge` (SwiftUI), `UIHingeInteraction` / `UIHinge` (UIKit) report angle and status (`closed`, `partiallyOpen`, `fullyOpen`). Apple's guidance: use it for interactions and effects, **not** for layout — layout follows size and reserved regions.
- **Split View** on the inner display is 50/50, each app ≈ 469 pt wide (compact-ish width while the size class stays regular).

## Compatibility behaviour: the SDK decides, not a plist key

The window an app gets is chosen by the SDK it was linked against (the `LC_BUILD_VERSION` stamp; check with `otool -l <binary> | grep -A4 LC_BUILD_VERSION`):

| Linked SDK | Closed (outer) | Open (inner) |
|---|---|---|
| ≤ iOS 26 | iPhone-mini-like window to the left of a letterbox where the vertical bar lives | same phone-shaped window **centered with an empty (black) frame** — "compatibility mode"; measured 375 × 667 pt scaled |
| iOS 27.0 | 386 × 678, black rail on the right, avoids the status bar | 871 × 669, horizontal bars only |
| **iOS 27.1 (Xcode 27.1)** | **466 × 678, edge to edge, vertical bar** | **951 × 669 edge to edge** |

So the first fix for any app that still shows a centered box with black bars is simply "build with Xcode 27.1". There is **no** Info.plist key, capability or build setting that opts in to the inner display (`UISupportsFoldable`, `UISupportsInnerDisplay`, `NSSupportsInnerDisplay` do not exist). Keys that *do* matter:

| Key | Effect on Duo |
|---|---|
| `UIApplicationSceneManifest` | **Mandatory** for iOS 27 SDK builds — apps without the scene lifecycle fail to launch. Flutter ≥ 3.41 migrates a stock `AppDelegate` automatically. |
| `UIRequiresFullScreen` | Deprecated (iOS 26) but still honoured: the app keeps its declared orientations and is **scaled/pillarboxed** on the inner display instead of laid out; it still resizes on open/close. Remove it (Apple TN3192); `UIRequiresFullScreenIgnoredStartingWithVersion` (iOS 26.2+) phases it out per version. A portrait-only app *without* the key is rotated into the inner display's wide orientation. |
| `UISupportedInterfaceOrientations` | Honoured on the outer display only. Keep all orientations listed; orientation locks are what produce letterboxing. |
| `UIApplicationSupportsMultipleScenes` | Opt-in to multiple windows (new on iPhone); not needed for layout fixes. |
| `TARGETED_DEVICE_FAMILY` | `1` (iPhone) is enough. Regular width on the inner display does **not** mean iPad; code that equates the two shows iPad-only layouts on the Duo. |

Open/close is a **trait and geometry change**, not a scene disconnect: the process stays alive, the window resizes live (like iPad multitasking), and `viewWillTransition(to:with:)` / `traitCollectionDidChange` / SwiftUI's environment fire. State must survive it.

## Numbers you will type into code

| Purpose | Value |
|---|---|
| Material / "medium" breakpoint where bottom bars become rails and 2-column grids become 3–4 | **600 pt** (outer 466 → compact; inner portrait 669 → medium; inner landscape 951 → expanded ≥ 840) |
| Phone-width column for the centered fallback | **466 pt** (outer width) or the app's design width; 430–480 is the usual range |
| Fold band to keep primary controls out of (book posture) | **x ≈ 455–496 of 951 pt**, i.e. the centre 40 pt ± 20 pt margins |
| Trailing rail inset when closed | **84 pt** |
| Deployment targets allowed by Xcode 27.1 | iOS 15–27; the new Duo APIs need `#available(iOS 27.1, *)` guards when the target is lower |

## Toolchain facts

- **Xcode 27.1 (27A9275)**, released 2026-10-15, is the first final Xcode with the iOS 27.1 SDK and the iPhone Duo simulator. Swift 6.4. Requires macOS Tahoe 26.6+ on Apple silicon. Xcode 27.0 (27A266a, 2026-09-14) has the iOS 27 SDK but no Duo support. Xcode 27.2 RC (27B48) ships an additional Duo-specific runtime `iOS-27-2-iPhone19-4`.
- **Device Hub** is Xcode 27's replacement for Simulator.app (`open -a DeviceHub`). It has Closed / Partially Open / Open pose buttons, an Option-drag hinge slider, rotate buttons, and screenshot/record buttons. There is **no `simctl` subcommand for fold state**; see `validation-on-device.md` for the ways around that.
- Simulator device type `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo` (alias `V68`), runtime `com.apple.CoreSimulator.SimRuntime.iOS-27-1`. `xcrun simctl io <udid> enumerate` lists displays `primary` (outer) and `primary-1` (inner).
- Known Xcode 27.1 simulator issues: first launch can take minutes; most app extensions cannot run in the Duo runtime; no cameras; keyboard shortcuts in Device Hub are off by default (`defaults -container com.apple.dt.Devices write com.apple.dt.Devices hostKeybindingPolicy -int 0`).
- UIKit 27.1: default `UIView` layout margins are now zero (`preservesSuperviewLayoutMargins = true` restores the old look). Mac Catalyst targets must guard 27.1-only APIs with `#if !targetEnvironment(macCatalyst)`.

## Apple's reading list (for the fresh-survey step)
- Preparing your app for iPhone Duo — developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- Three steps to make your app shine on iPhone Duo — developer.apple.com/iphone-duo/prepare/ (includes `xcrun agent skills export` for Xcode's App Resizability skill)
- HIG: Designing for iPhone Duo — developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo
- Group Lab summary — developer.apple.com/forums/thread/847644
- Tech Talks: 111466 Design, 111461 Prepare your app, 111462 Raise the bar (toolbars), 111463 Strike a pose (adaptive layouts), 111464 Multiple displays and scenes, 111465 Camera
- Interacting with your app in Device Hub — developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub
- Community samples: github.com/artemnovichkov/iPhone-Duo-by-Examples (SwiftUI), github.com/astralchen/iphone-duo-sample (UIKit)
