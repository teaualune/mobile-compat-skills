# Swift playbook for iPhone Duo (SwiftUI and UIKit)

How to fix a native screen for Duo. Numbers are in `duo-device-facts.md`; the full API inventory in `baseline-survey.md` (read only when `detect_stack.sh` says `survey=stale`). Helper source is in `assets/helpers/DuoCenteredColumn.swift` (SwiftUI) and `assets/helpers/DuoColumnContainerViewController.swift` (UIKit) — read in Phase 3 when you implement, not before.

## What iOS 27.1 gives you
- **Size classes drive everything.** Outer display compact-width; inner display **regular × regular in both orientations**. `@Environment(\.horizontalSizeClass)` / `traitCollection.horizontalSizeClass`. Regular width is *not* iPad — never route it through iPad-only code.
- **System containers adapt for free.** `NavigationSplitView`/`UISplitViewController` collapse on outer, tile on inner. `TabView`/`UITabBarController` move into the vertical bar (`.defaultTabBarPlacement(.sidebar)` / `tabBarController.sidebar.preferredPlacement = .sidebar` on inner). Sheets center on inner; `presentationPlacement(_:)` / `UISheetPresentationController.preferredPlacement` pick a side.
- **Vertical bars** take items from `NavigationStack`/`TabView`/`UINavigationController`/`UITabBarController` only; items need **icon + title**. Opt out per screen with `.toolbarVerticalBehavior(.disabled)` / `preferredVerticalBarBehavior = .disabled`; `@Environment(\.toolbarVerticalEdge)` / `traitCollection.verticalBarEdge` tells the edge.
- **Reserved regions**: `GeometryProxy.reservedRegions(kind:)` / `UIView.reservedRegions(kind:)` — `.division` (fold, active only when partially folded) and `.occlusion` (cameras). Read after layout; never cache.
- **Two-pane**: `ArrangementView` / `UIArrangementViewController` (split or overlay on the crease). Don't nest in `NavigationSplitView`, `List`, `ScrollView`.
- **Hinge**: `onHingeChange` / `UIHingeInteraction` — effects, not layout.
- Guard 27.1 APIs with `#available(iOS 27.1, *)` when the target is lower.

Lost: `UIScreen.main` (deprecated iOS 26) describes the **outer** display even while on the inner one; orientation APIs are meaningless for layout. Width vs height of `view.bounds` is the only honest orientation signal.

## Two strategies
**A. Adaptive (preferred).** Size classes choose columns, rail/sidebar vs bottom bar, `NavigationSplitView` for master/detail, media by aspect ratio. For lists, grids, forms, dashboards, media.

**B. Centered column (fallback).** Interactive content capped at phone width (466 pt, or the design width) and centered; background colour/gradient/image fills the window. What pre-Xcode-27 builds look like minus the black frame. For bespoke compositions or when the caller asks. Legitimate only if the surround carries the app's background. Use `DuoCenteredColumn` (SwiftUI modifier) or `DuoColumnContainerViewController` (UIKit child container) from `assets/helpers/`; keep `NavigationStack`/`TabView` outside it so the system still gets its bars.

Mixing per screen is normal.

## Symptom → cause → fix
| Symptom in screenshot | Root cause | Fix |
|---|---|---|
| Phone-shaped box centered in a black frame | linked against ≤ iOS 26 SDK | build with Xcode 27.1; nothing else fixes this |
| App rotated to wide orientation on inner, or pillarboxed/scaled | portrait-only; `UIRequiresFullScreen` set → scaled, unset → rotated | remove the key, support all orientations, lay out by width |
| Gradient/image stops at a phone-sized rectangle | `.frame(width: 393, height: 852)` / fixed background constraints | background `.ignoresSafeArea()` with no frame; UIKit: pin background to superview edges, not the content column |
| Hero image cropped to a band | `.scaledToFill` + `.clipped()` on a width from `UIScreen.main` | size by aspect (`.aspectRatio(16/9, contentMode: .fit)`) inside a max-width container; fill vs fit by size class |
| Tab items 300 pt apart; two buttons at far edges | custom `HStack { Spacer() }` bar, `spacing: 400`, `.equalSpacing` across full width | `TabView`/`UITabBarController`; fixed spacing in a phone-width column; `ViewThatFits` |
| Button clipped at bottom | `height = UIScreen.main.bounds.height - N` | remove arithmetic; `VStack { … Spacer(); button }`; `ScrollView` + `.frame(minHeight:)` |
| Content under the trailing rail; FAB/toast hidden | symmetric safe-area assumptions | per-side insets (`.safeAreaPadding`, `bounds.inset(by: safeAreaInsets)`); never `padding(.horizontal, insets.left)` |
| iPad-only layout (inspector, 3 columns) appears | `horizontalSizeClass == .regular` treated as iPad | decide by `NavigationSplitView` column visibility / `isCollapsed`, not idiom |
| Toolbar items vanish; empty rail | text-only `UIBarButtonItem` / `Button("Done")` | icon + title; `visibilityPriority`, `ToolbarOverflowMenu`, `.cancellationAction`; or disable the vertical bar on that screen |
| Primary control in the crease (book pose) | centered CTA at x≈475 | `reservedRegions(kind: .division)` offset; `ArrangementView` for two-pane screens |
| Stale layout after fold/unfold | sizes read once in `viewDidLoad`/`init`; cached `UIScreen.main.bounds` | lay out in `layoutSubviews`/`viewDidLayoutSubviews`; `onGeometryChange`; `registerForTraitChanges` |
| Lost scroll/form state across fold | treated as scene teardown | it is a trait change; keep state in the model; `stateRestorationActivity` only for real disconnects |
| Margins differ after rebuilding with 27.1 | `UIView` default layout margins are now zero | `preservesSuperviewLayoutMargins = true` |

## Project settings (go in the plan when present)
- **Xcode 27.1**; the linked SDK decides the window (`scripts/check_app_sdk.sh` confirms a built `.app`).
- `UIApplicationSceneManifest` (or `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES`) must exist — iOS 27 SDK builds without the scene lifecycle fail to launch. AppDelegate-only `UIWindow` → `UIWindow(windowScene:)` in a `SceneDelegate`.
- Remove `UIRequiresFullScreen` / `INFOPLIST_KEY_UIRequiresFullScreen`; staged rollout via `UIRequiresFullScreenIgnoredStartingWithVersion`.
- `UISupportedInterfaceOrientations(_iPhone)`: portrait + both landscapes.
- `TARGETED_DEVICE_FAMILY = 1` is enough. Mac Catalyst targets: `#if !targetEnvironment(macCatalyst)` around 27.1 APIs.

## Things that silently break
- Every `UIScreen.main.*` read (`detect_stack.sh` counts them; each is a planned change). Replacement: `view.window?.windowScene?.screen` when a screen is truly needed; else `view.bounds` / `GeometryReader`; `traitCollection.displayScale` for scale.
- Device-size checks (`bounds.height == 844`), `UIDevice.current.orientation` for layout.
- Hand-placed `UIToolbar`/`UITabBar`/`UINavigationBar` and SwiftUI `HStack` bars — they neither move into the vertical bar nor avoid the rail.
- `.frame(width: UIScreen.main.bounds.width)` "full-bleed" tricks → an outer-width band on the inner display. Use `.containerRelativeFrame(.horizontal)` or no width.
- Xcode 27.1 Previews have a "Display" override for the inner display; useful for a look, but Phase 4 still needs the simulator or device.
