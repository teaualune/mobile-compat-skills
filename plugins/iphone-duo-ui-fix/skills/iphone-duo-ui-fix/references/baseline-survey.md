# Baseline survey — iPhone Duo tooling for Flutter and Swift

**Survey date: 2026-10-30.** This is the "known good" snapshot Phase 1 compares the project against. Keep this file as it is; a fresh survey is presented in the conversation (never written into the project) and supersedes it for that run.

## Versions this survey was done against

| Component | Version at survey | How to read the project's value |
|---|---|---|
| Xcode | **27.1 (27A9275)**, released 2026-10-15; Xcode 27.2 RC 27B48 existed but was not final | `scripts/check_xcode.sh` → `xcode_version` |
| iOS SDK | 27.1 | `check_xcode.sh` → `ios_sdk` |
| Swift | 6.4 | `check_xcode.sh` → `swift_version` |
| Flutter stable | **3.47.9** (2026-10-29), Dart 3.13.7 | `detect_stack.sh` → `installed_flutter`, `fvm_flutter`, `lock_flutter_sdk` |
| Flutter beta | 3.50.0-0.3.pre (2026-10-28), Dart 3.14.0-315.3.beta; 3.50 stable targeted for November 2026 | |
| iOS on device | 27.1 (27.2 released 2026-10-26) | |

### When the baseline is "current enough"
`scripts/detect_stack.sh` applies this rule and prints `survey=current|stale` (constants at the top of its survey block mirror this table — update both when the survey is redone):
- Xcode line 27.1 or 27.2, **and**
- Flutter (if Flutter) line 3.47 or 3.50 — installed or fvm-pinned; a pubspec lower bound only counts when it is *newer* than these lines, **and**
- every foldable/adaptive-looking package in `pubspec.yaml` is listed below, **and**
- the baseline is less than ~100 days old.

`survey=current` → offer to skip; this file need not be opened unless a Flutter package decision comes up. `survey=stale` → run the checklist at the end of this file.

---

## Flutter

### Framework support (as of 3.47.9 stable / 3.50 beta)
- `MediaQuery.displayFeatures` is **empty on iOS**. The engine PR that populates it from iOS 27.1 reserved regions (flutter/flutter#193025) is open and blocked until Flutter CI moves from Xcode 26.2 to 27.1. `DisplayFeatureSubScreen`, `TwoPane`-style snapping and posture logic therefore need a package bridge.
- `PlatformDispatcher.instance.displays` reports the **outer** display while on the inner one; fixed on master 2026-10-28 (#195199), not in 3.47.9 or the 3.50 beta.
- Physical-device bug: blank Flutter view on a cold start while unfolded (#195401, open) — `CADisplayLink` bound to the outer `UIScreen`.
- UIScene lifecycle required for iOS 27 SDK builds; Flutter ≥ 3.41 auto-migrates a stock `AppDelegate` (`docs.flutter.dev/release/breaking-changes/uiscenedelegate`).
- The app template does not set `UIRequiresFullScreen`; template deployment target is 15.0 since 3.47. Pods at 13.0 against a 15.0 Runner fail on Xcode 27.1.
- Known 3.47–3.49 glitches right after fold/unfold: AppBar title offset (#193202), caret (#193208), autocomplete overlay (#193217). Tab bars stay at the bottom instead of the vertical bar (#193035, #193878 — design discussion open).
- No built-in window-size-class API; Material breakpoints by hand (600 / 840).

### Packages (pub.dev, 2026-10-30)

Duo-specific, all published Sept–Oct 2026 and all needing an Xcode 27.1 build to receive data:

| Package | Version | Platforms | Min Flutter | What it gives | Notes |
|---|---|---|---|---|---|
| `foldable` | 1.0.5 (2026-09-26) | iOS only | 3.24 | `Foldable.isFoldable`, `hingeAngleStream`, `hingeStatusStream`, `.division`/`.occlusion` regions with `isActive`; `FoldableProvider(bridgeMode: none|cutoutsOnly|full)` injects into `MediaQuery.displayFeatures`; `FoldAwareBuilder`; `DuoMediaQuery.horizontalSizeClassOf` | Author also wrote the Flutter engine PR; linked from flutter#193054 as the interim solution. Default bridge `none` on purpose (full splits dialogs). |
| `unfold` (ex `duo_layout`) | 0.2.0 (2026-10-21) | iOS + Android | 3.44 | `DeviceGeometryScope` (`foldOf`, `hingeOf`, `horizontalSizeClassOf`, `sideStripOf`), `FoldSplit`, `TabletopSplit`, `OcclusionSafeArea`, `HingeAngleBuilder`, `AdaptiveNavigationScaffold` (bottom bar / rail / vertical bar), `DisplayFeatureBridge` | Most complete scaffold-level option; SwiftPM + CocoaPods. |
| `fold_kit` | 1.1.1 (2026-10-29) | iOS + Android | 3.44 | `FoldInfo` (posture, fold rect, window size class), hinge angle, `FoldTwoPane`, `FoldScaffold`, `FoldAvoid`, `FoldPreview`, `dart run fold_kit:audit` | Has an audit command that flags `setPreferredOrientations`, cached sizes, etc. |
| `duo_display` | 1.0.1 (2026-10-16) | iOS only | 3.44 | `DuoDisplayFeatures` above `MaterialApp` (fold + cameras into `displayFeatures`), `DuoLayoutBuilder(splitWhenFlat:)` | Simulator-tested only; README has measured sizes. |
| `duo_kit` | 0.1.1 (2026-10-15) | pure Dart | 3.41 | `FoldGeometry`, `FoldScaffold`, `FoldSplitView`, `FoldAnchor`, debug pose simulator, test poses | Needs `foldable` with `bridgeMode: full` on iOS. |
| `foldable_device` | 1.0.2 (2026-10-25) | iOS + Android | 3.3 | posture, hinge angle, fold direction, reserved regions | Android foldables + Duo in one API. |

Generic adaptive layout:

| Package | Version | Status | Use |
|---|---|---|---|
| `responsive_framework` | 1.5.1 (2024-08) | maintained-ish, no release 2 yrs | breakpoints, `MaxWidthBox`, `ResponsiveValue`; fine if already present — check breakpoints split at ~600 |
| `custom_adaptive_scaffold` | 5.3.0 (2026-07) / 6.0.0-dev | maintained fork | replacement for the discontinued official scaffold |
| `flutter_adaptive_scaffold` | 0.3.3+1 | **discontinued** | keep if present, do not add |
| `adaptive_breakpoints` | 0.1.7 | **discontinued** | same |
| `dual_screen` | 1.0.4 (2023) | Android-only Surface Duo, stale | not applicable to iPhone Duo |
| `window_manager`, `flutter_displaymode` | — | desktop / Android | not relevant |

### Recommendation baked into the playbook
Framework primitives (`LayoutBuilder`, `MediaQuery.sizeOf`, `ConstrainedBox`, `NavigationRail`, `SafeArea` per side) plus a small `DuoLayout` helper meet the baseline with no new dependency. Add `unfold` or `fold_kit` when the plan needs posture/fold geometry or navigation in the vertical bar; add `foldable` when only iOS hinge data is needed. Pin exact versions; these packages are weeks old.

---

## Swift (iOS 27.1 SDK)

API inventory used by the playbook — all `iOS 27.1` unless noted:

| Area | SwiftUI | UIKit |
|---|---|---|
| Size classes | `@Environment(\.horizontalSizeClass)` — inner display regular × regular (iOS 27.0 behaviour) | `traitCollection.horizontalSizeClass` |
| Vertical bar | `.toolbarVerticalBehavior(.disabled)`, `.toolbarVerticalCompressionBehavior(.prefersTabBar/.prefersToolbarItems)`, `ToolbarContent.axisBehavior`, `visibilityPriority`, `ToolbarOverflowMenu`, `.cancellationAction`, `.topBarPinnedTrailing`, `@Environment(\.toolbarVerticalEdge)` | `UIViewController.preferredVerticalBarBehavior`, `navigationItem.verticalBarCompressionBehavior`, `UIBarButtonItem.axisBehavior`, `.visibilityPriority`, `navigationItem.additionalOverflowItems`, `pinnedTrailingGroup`, `UITraitCollection.verticalBarEdge` |
| Reserved regions | `ReservedRegion` (`frame`, `margins`, `isActive`, `kind: .division/.occlusion`), `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` | `UIView.ReservedRegion`, `UIView.reservedRegions(kind:options:)` |
| Hinge | `View.onHingeChange(isEnabled:_:)`, `DeviceHingeContext`, `DeviceHinge.angle/.status` | `UIHingeInteraction(updateHandler:)`, `UIHinge.angle/.status` |
| Two-pane | `ArrangementView`, `.arrangementViewStyle(.split/.overlay)`, `splitArrangementLayoutRatio`, `overlayArrangementEdge` | `UIArrangementViewController`, `UISplitArrangement`, `UIOverlayArrangement` |
| Navigation | `NavigationSplitView`, `TabView` + `.defaultTabBarPlacement(.sidebar)`, `presentationPlacement(_:)` (27.0) | `UISplitViewController`, `UITabBarController.sidebar.preferredPlacement`, `UISheetPresentationController.preferredPlacement` |
| Multiple scenes | `UIApplicationSupportsMultipleScenes`, `.sceneAccessory { CameraCaptureAccessory }` | `UIWindowScene.ActivationAction`, `UISceneAccessory.cameraCapture`, `registerSceneAccessory` |
| Deprecated / avoid | — | `UIScreen.main` (iOS 26), `UIRequiresFullScreen` (iOS 26, still honoured), orientation APIs for layout |

Sessions: Tech Talks 111461 (Prepare), 111462 (toolbars), 111463 (adaptive layouts), 111464 (scenes), 111466 (design); WWDC26 278 (Modernize your UIKit app). No official Apple sample project as of the survey; community samples listed in `duo-device-facts.md`.

---

## Fresh-survey checklist (when the baseline is not current)

Run these and present the result in the conversation in the same shape as this file (what changed versus the baseline first, then the tables); carry the chosen packages/versions into the plan's Dependencies section:
1. Versions: `check_xcode.sh`; `flutter --version`; `curl -s https://api.github.com/repos/flutter/flutter/releases?per_page=5` (or the releases page) for stable/beta.
2. Flutter framework: search `github.com/flutter/flutter` issues/PRs for "iPhone Duo", "displayFeatures iOS", "hinge", "reservedRegions"; check whether #193025 (displayFeatures on iOS) and #195199 (correct UIScreen) have shipped in a stable release; check `api.flutter.dev` `MediaQueryData.displayFeatures` docs for the "Android only" note.
3. pub.dev: `https://pub.dev/api/packages/<name>` for each package above plus a search for "iPhone Duo", "foldable", "hinge"; note new packages, latest versions, discontinued flags.
4. Apple: Xcode release notes (`developer.apple.com/documentation/xcode-release-notes`), the "Preparing your app for iPhone Duo" overview, and the Group Lab thread for new APIs or changed behaviour; `xcrun simctl list devicetypes | grep -i duo` for new simulator profiles.
5. Record what changed versus this baseline at the top of the new file, then update `scripts/detect_stack.sh`'s `FOLD_PKGS` list if new packages appeared.
