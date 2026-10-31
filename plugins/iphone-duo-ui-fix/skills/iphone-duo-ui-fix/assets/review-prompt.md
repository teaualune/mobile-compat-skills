# Review prompt template (Phase 5)

Spawn one subagent per concern. Replace the angle-bracket fields. Give each reviewer the plan and the diff but *not* the implementation conversation — fresh eyes are the point.

---

You are reviewing a change set that adapts a mobile app's UI to iPhone Duo, Apple's foldable iPhone with a narrow outer display and a wide, nearly square inner display. Apps that assume a phone-shaped window break on the inner display; apps that over-correct break on the outer display or on regular iPhones.

Repository: `<path>`
Stack: `<native iOS SwiftUI/UIKit | Flutter x.y.z>`
Plan the author worked from (read it first): <paste the approved plan here>.
Changes to review: `git diff` of the working tree (read-only), or the files listed under "File touch list" in the plan.
Device facts and API reference: `<skill path>/references/duo-device-facts.md` and the stack playbook `<skill path>/references/<swift|flutter>-playbook.md`.

Your single concern for this review: **<one of the three below>**

1. *Layout correctness across displays and fold transitions.* For every changed view, reason about four states: outer display, inner display in landscape (the default when opened), inner display in portrait (rotated), and the moment of folding/unfolding while the view is on screen. Flag any place that reads a size once and caches it, any hard-coded width/height, any `UIScreen.main`-style global screen query, any breakpoint that is correct for one display but wrong for the other, any background layer that will not reach the window edges, and any interactive control that can end up clipped or under the hinge region. Say which display/state each finding affects.

2. *Regression risk on non-Duo devices.* Consider regular iPhones (compact width), iPhone landscape, and iPad (regular width). Flag changes where the new adaptive branch will fire on iPad or landscape phones with a layout that was not intended for them, size-class assumptions that conflate "regular width" with "inner display", and any behaviour that now differs for existing users on current hardware.

3. *Code quality and idiom.* Does the change follow the surrounding code's patterns (state management, theming, layout helpers, naming)? Is the new shared helper (if any) placed where the team would look for it, documented, and used consistently rather than copy-pasted? Any dead code, leftover debug values, or TODOs that should be resolved before merge?

Report format — be concrete, one finding per bullet, ordered by severity:

### Must fix before merge
- `path/file.ext:line` — what is wrong, which display/state it affects, suggested fix.

### Should fix
- ...

### Nits / optional
- ...

### What is done well
- one or two bullets, so the author knows what to keep doing.

Do not rewrite the code yourself; describe the fix. If you need to run `flutter analyze` / `xcodebuild build` to confirm something, do so and quote the relevant line of output.
