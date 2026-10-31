# Validating on an iPhone Duo (Device Hub simulator or physical device)

Read this in Phase 4 when the caller asked you to validate. Everything here runs on the Mac that has Xcode 27.1: directly when the session is on that Mac, or through the device-bridge shell when the session is in the cloud. If neither is available, hand the caller `assets/validation-checklist.md` instead.

## 0. Confirm the build is a 27.1-SDK build

A build linked against an older SDK is letterboxed by the system no matter what the code does, so check before judging any screenshot:

```bash
APP=<path to .app>; BIN="$APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
otool -l "$BIN" | grep -A4 LC_BUILD_VERSION        # want:  sdk 27.1
```

`scripts/check_app_sdk.sh <path.app>` does the same and exits non-zero below 27.1.

## 1. Simulator (Device Hub)

Device Hub replaced Simulator.app in Xcode 27 (`open -a DeviceHub`). The Duo lives in the iOS 27.1 runtime; the device type contains only the Duo.

```bash
xcrun simctl list runtimes | grep -i 27        # need com.apple.CoreSimulator.SimRuntime.iOS-27-1 (or iOS-27-2-iPhone19-4)
xcodebuild -downloadPlatform iOS                # if the runtime is missing (Xcode > Settings > Components also works)
xcrun simctl list devices | grep -i duo         # existing Duo simulators and their UDIDs
xcrun simctl create "Duo-27.1" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1
xcrun simctl boot <udid> && xcrun simctl bootstatus <udid> -b
open -a DeviceHub                               # first launch of a Duo simulator can take minutes (known 27.1 issue)
```

Build and install:
- Native: `xcodebuild -scheme <Scheme> -destination 'platform=iOS Simulator,name=Duo-27.1' -derivedDataPath build build`, then `xcrun simctl install <udid> build/Build/Products/Debug-iphonesimulator/<App>.app` and `xcrun simctl launch <udid> <bundle id>`.
- Flutter: `flutter run -d <udid>` (keeps a hot-reload session; use `--no-resident` for a plain launch) or `flutter build ios --simulator` then `simctl install`/`launch` as above.

### Poses and rotation
There is **no `simctl` subcommand for fold state** (Apple forum 847883, flutter#195350). Options, in order of preference:
1. **Device Hub buttons.** Right of *Rotate Right* there are three pose buttons: Closed, Partially Open, Open; Option-drag the slider under the bezel for an arbitrary angle; *Controls > Rotate Left/Right* for orientation. When the session has desktop control (computer-use tools), click these; take a screenshot of Device Hub first to find them.
2. **Community CLIs** (send the same private HID hinge event Device Hub uses; may break with an Xcode update — fall back to the buttons if they stop working):
   - `brew install artemnovichkov/tap/hinge` → `hinge 180` (open), `hinge 0` (closed), `hinge 90`, `hinge get`
   - `brew install skarol/tap/duoctl` → `duoctl open|close|half`, `duoctl hinge <deg>`, `duoctl rotate portrait|landscape`, `duoctl screenshot out.png`, `duoctl state`
   - `devicehubctl <udid> pose closed|partial|open` drives Device Hub through the accessibility API.
   Ask the caller before installing anything on their Mac.
3. Read-only checks: `xcrun devicectl device motion hinge-angle`, `xcrun devicectl device info displays`.

`XCUIDevice.shared.orientation` and `devicectl device orientation set` do not change the Duo simulator's pose. Do not use `simctl io screenConfig --display=primary power off` (crashes the simulator).

Orientation locks stick per bundle id until the simulator reboots: after removing `UIRequiresFullScreen` / `setPreferredOrientations`, `xcrun simctl shutdown <udid> && xcrun simctl boot <udid>` before re-checking.

### Screenshots
```bash
xcrun simctl io <udid> enumerate | grep -iE 'display|primary'     # primary = outer, primary-1 = inner (some builds: --display=1 / 3)
xcrun simctl io <udid> screenshot --type=png --display=primary   outer.png
xcrun simctl io <udid> screenshot --type=png --display=primary-1 inner.png
```
Without `--display`, `simctl io booted screenshot` captures the inner display even while folded (you get a black image). An inactive display captures black; wait 1–3 s after a pose change. `scripts/capture_duo_screens.sh <out_root> <outer|inner|inner_portrait> <name> --display primary-1` wraps this and saves into the same folder layout as the input screenshots, so before/after pairs line up. Device Hub's own screenshot button saves to the Desktop.

### A validation pass, per screen
1. Open → inner landscape (951 × 669) → navigate to the screen → capture into `inner/`.
2. Rotate → inner portrait (669 × 951) → capture into `inner_portrait/` (quick look only; it is rarely broken).
3. Closed pose → outer (466 × 678) → capture into `outer/`.
4. With the screen still showing: close → open → close. Watch for a stale layout, a jumped scroll position, lost input, a dialog that got confined to half the screen.
5. Partially Open (book, ~127°): is any primary control sitting in the crease band?
6. Look at every capture with the Read tool and grade it against the checklist's definition of pass. Put the captures next to the originals and present them as before/after.

## 2. Physical iPhone Duo

```bash
xcrun devicectl list devices                                   # paired devices (needs Xcode 27.1, iOS 27.1 on the phone)
xcrun devicectl device install app --device <id> <path.app>    # a device build: xcodebuild -destination 'generic/platform=iOS' / flutter build ios --debug
xcrun devicectl device process launch --device <id> <bundle id>
xcrun devicectl device motion hinge-angle --device <id>        # read-only
```
`flutter run -d <device id>` works too. Fold state on hardware is the caller's hand: ask them to hold the pose while you capture. Screenshots of a physical device come from Xcode's Devices and Simulators window, QuickTime screen recording, or `idevicescreenshot` (libimobiledevice, `brew install libimobiledevice`); `devicectl` has no screenshot command. Simplest is to ask the caller to take screenshots on the phone and AirDrop/attach them into the same `outer/`, `inner/`, `inner_portrait/` layout.

Flutter-specific: a blank first frame when the phone is launched already open is flutter/flutter#195401 (engine bug), not a layout regression — note it and move on.

## 3. What to report back
For each screen in the plan: pass / acceptable-with-note / fail per column of the checklist, the before/after pair, and one line on anything you saw on a screen that was *not* in the plan. Then ask the caller whether they are satisfied, want another iteration on a named screen, or want to stop here.
