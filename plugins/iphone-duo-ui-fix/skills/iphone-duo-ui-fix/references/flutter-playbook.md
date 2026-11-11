# Flutter playbook for iPhone Duo

How to fix a Flutter screen for Duo. Numbers are in `duo-device-facts.md`; package versions in `baseline-survey.md` (read only when `detect_stack.sh` says `survey=stale` or a package decision is needed). Helper source is in `assets/helpers/duo_layout.dart` — read it in Phase 3 when you implement, not before.

## What Flutter gives you on Duo today
- **The window resizes on fold/unfold** like iPad multitasking. `MediaQuery.sizeOf(context)` and `LayoutBuilder` track the live window. Branch on width, never on device type.
- **`MediaQuery.displayFeatures` is empty on iOS** in every shipped Flutter (3.47 stable, 3.50 beta); the engine PR is blocked on Flutter CI's Xcode. Hinge/posture APIs do nothing without a package bridge.
- **`MediaQuery.padding` is asymmetric** on Duo (~84 pt trailing rail when closed). Read per side; never build symmetric padding from one side.
- **No size-class API.** Use Material widths: compact < 600, medium 600–839, expanded ≥ 840. Duo: outer 466 → compact; inner portrait 669 → medium; inner landscape 951 → expanded. Opening the phone crosses two breakpoints at once.
- Flutter-drawn bottom bars stay at the bottom (they don't move into iOS's vertical bar). Acceptable, but at ≥ 600 switch to `NavigationRail` or center the bar in a column.

## Two strategies
**A. Adaptive (preferred).** More grid columns from `maxCrossAxisExtent`, rail instead of bottom bar at ≥ 600, master/detail where the design has one, media sized by aspect ratio. For lists, grids, forms, dashboards, media.

**B. Centered column (fallback).** Interactive content capped at phone width (466 pt, or 430–480) and centered; the non-interactive background (colour/gradient/image) fills the whole window. What pre-Xcode-27 builds look like minus the black bars. For bespoke compositions (onboarding, designed landing pages) or when the caller asks. Legitimate only if the surround carries the app's background. Use `DuoLayout` (`assets/helpers/duo_layout.dart`) app-wide in `MaterialApp.builder` or per screen.

Mixing per screen is normal.

## Symptom → cause → fix
| Symptom in screenshot | Root cause | Fix |
|---|---|---|
| Hero image cropped to a band / stretched | `SizedBox(width: screenW, height: screenW*k)` + `fitHeight/fitWidth` | `AspectRatio(16/9, child: Image(fit: BoxFit.cover))`, optionally `ConstrainedBox(maxHeight:)` |
| Background stops partway; black/white side bands | Background painted inside a width-limited container | Paint on `Scaffold.backgroundColor` or a `DecoratedBox` around the whole body; constrain content only |
| Bottom tab items spread far apart | `BottomNavigationBar` on a 951 pt window | `NavigationRail` when `width >= 600`; or center the bar inside `DuoLayout` |
| Button pushed below the visible area | `size.height - N` measured on a regular iPhone | Remove arithmetic; `SafeArea` + `Expanded`/`Spacer`; `SingleChildScrollView` + `ConstrainedBox(minHeight: constraints.maxHeight)` for "button at bottom, scroll if short" |
| Grid: 2 enormous columns | `crossAxisCount: 2` | `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220)` |
| Form fields 900 pt wide | unconstrained `Column` | `Center(child: ConstrainedBox(maxWidth: 560))` |
| Two buttons flung to opposite edges | `Row(spaceBetween)` / `Spacer()` on a wide window | Fixed `spacing` inside the content column; `Wrap`/`OverflowBar` |
| Layout stale after unfold | width read in `initState` or cached in a field | Read `MediaQuery.sizeOf`/`LayoutBuilder` inside `build`; never cache window size |
| App rotates when unfolded, or is pillarboxed with black bars | Portrait-only: without `UIRequiresFullScreen` iOS rotates it; with it, iOS letterboxes | Support all orientations (drop `setPreferredOrientations`), lay out by width, remove the key |
| Dialog/sheet confined to half the screen | a package injected a `fold` with `postureHalfOpened` → `DisplayFeatureSubScreen` | keep the bridge at `none`/`cutoutsOnly`, or pass `anchorPoint` |
| Content under the vertical bar | body not in `SafeArea`; symmetric padding from one side | `SafeArea` around the body; `MediaQuery.paddingOf` per side |
| Text, icons and spacing oversized (or squashed vertically) on the inner display | `flutter_screenutil` `.w`/`.h`/`.sp`/`.r` scale by the window against a phone `designSize` | stop scaling past compact width — a `designSize` per width class in `ScreenUtilInit`, `minTextAdapt` for text; check the outer display too |

"Width" always means the width the widget is given (`LayoutBuilder`) or the window (`MediaQuery.sizeOf`), never `View.of(context).display.size` and never a literal. Read the table backwards for a screen without a screenshot: the cause found in code predicts the symptom.

## Layout patterns → mechanism
What each pattern should look like, and its Duo rules, are in `layout-patterns.md`. Branch with `LayoutBuilder` / `MediaQuery.sizeOf` at the Material widths above (`DuoLayout.isWide` is the medium test).

| Pattern | Mechanism |
|---|---|
| `global-nav` | `NavigationBar` below medium → leading `NavigationRail` from medium (`extended: true` or `NavigationDrawer` at expanded); one selected-index state for both. `unfold`'s `AdaptiveNavigationScaffold` only if that package was chosen. |
| `list-detail` | At expanded `Row(list, VerticalDivider, Expanded(detail))`; below it the existing push. The selected id lives above both (state or router), so folding pushes the open item and unfolding shows it in the pane; with go_router, one route that renders either form. `FoldTwoPane` / `FoldSplit` only if that package was chosen. |
| `cards-feed` | `SliverGridDelegateWithFixedCrossAxisCount` with `crossAxisCount` 1 / 2 / 3 by width class and a fixed `childAspectRatio`; or `MaxCrossAxisExtent` sized so compact stays one column |
| `long-form` | `Center` + `ConstrainedBox(constraints: BoxConstraints(maxWidth:))` around the text; at expanded a `Row` with a TOC panel |
| `bottom-sheet` | From medium: `showDialog` with a width-capped `Dialog`, or `MenuAnchor` / `showMenu` anchored to the trigger for short choices. `showModalBottomSheet(constraints:)` is the baseline. With a `displayFeatures` bridge on, mind `anchorPoint` (symptom table). |
| `primary-cta` | Below medium the existing footer button; from medium `Align(alignment: AlignmentDirectional.bottomEnd)` + `SizedBox(width:)`, or the button moved to the end of the content column; `FloatingActionButton.extended` at `endFloat` also fits |
| `form` | Label/field `Row` (fixed label width, `Expanded` field) from medium; two `Column`s of grouped `Card`s at expanded, each in a `FocusTraversalGroup` so Next stays in its column |
| `media` | `Flex(direction: wide ? Axis.horizontal : Axis.vertical)` keeps the player's element (swapping `Row` ↔ `Column` would recreate it); a `GlobalKey` if the player moves between parents |
| `canvas-tools` | `Row(children: [Expanded(canvas), SizedBox(width:, child: inspector)])` at expanded; `endDrawer` or bottom sheet below |
| `flex-mode` | Needs a fold package (`foldable`, `fold_kit`, `unfold`) — `displayFeatures` is empty on iOS; split on the fold bounds it reports, never a hard-coded position |

## Toolchain rules (go in the plan when present)
- Build with **Xcode 27.1 / iOS 27.1 SDK**; the SDK, not a plist key, decides the window.
- **UIScene lifecycle is mandatory** for iOS 27 SDK builds. Flutter ≥ 3.41 migrates a stock `AppDelegate` on `flutter run`/`build ios`; a customised one needs the manual migration (`FlutterImplicitEngineDelegate`, `UIApplicationSceneManifest`, `SceneDelegate: FlutterSceneDelegate`). `detect_stack.sh` → `appdelegate_custom=` + `plist_UIApplicationSceneManifest=`.
- **Remove `UIRequiresFullScreen`** (still honoured: scales/pillarboxes the app). `UIRequiresFullScreenIgnoredStartingWithVersion` for staged rollouts.
- Pods at `platform :ios, '13.0'` against the 15.0 Runner fail on Xcode 27.1 — bump together.
- Keep all orientations in `UISupportedInterfaceOrientations`.

## Packages: only when a plain helper is not enough
| Need | Use |
|---|---|
| Width-based layout, centered column | nothing — framework + `DuoLayout` |
| Hinge angle / posture, tabletop layouts | `foldable` (iOS-only) or `fold_kit` / `unfold` (iOS + Android) |
| Populate `displayFeatures` for existing sub-screen-aware code | `foldable` `FoldableProvider(bridgeMode:)`, `duo_display`, `unfold` `DisplayFeatureBridge` — start with cutouts-only |
| Navigation in the vertical bar, split on the crease | `unfold` (`AdaptiveNavigationScaffold`, `FoldSplit`) or `fold_kit` (`FoldScaffold`, `FoldTwoPane`) |
| Already present: `responsive_framework` | fine; check its breakpoints split at ~600 |
| Already present: `flutter_adaptive_scaffold` / `adaptive_breakpoints` | discontinued — keep, don't add; `custom_adaptive_scaffold` is the fork |
| `dual_screen` | Android Surface Duo only, stale |
All Duo packages need an Xcode 27.1 build to receive data; pin exact versions.

## Known framework issues (note, don't "fix" with layout hacks)
- `PlatformDispatcher.displays` / `View.display` report the **outer** display on shipped versions (fixed on master 2026-10-28).
- Physical Duo, cold start while unfolded → blank first frame (flutter/flutter#195401, open).
- AppBar title offset, caret and autocomplete glitches right after fold/unfold on 3.47–3.49.
- Simulator orientation locks stick per bundle id until reboot — reboot after removing `setPreferredOrientations`.
- Split View makes the app `inactive` while visible; pause media on `paused`, not `inactive`.
