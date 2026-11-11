# iPhone Duo validation checklist — <app name> — <date>

Fill one row per screen that was touched (plus 1–2 untouched screens as a regression spot-check).
✅ pass · ⚠️ acceptable with note · ❌ fail (describe) · — not applicable
*Before*: `screenshot` or `none` — a `none` screen has never been seen on a Duo, so check every column; its defects were predicted from code.

| Screen | Before | Outer | Inner (landscape) | Inner portrait | Partially folded | Fold → unfold on screen | Unfold → fold on screen | Notes |
|--------|--------|-------|-------------------|----------------|------------------|--------------------------|--------------------------|-------|
| | | | | | | | | |

## What "pass" means (the baseline the skill promises)
- Every interactive control is fully on screen and tappable; nothing is clipped by edges, the hinge region, or the safe area.
- No visual break: backgrounds, gradients and hero images reach the edges of the area they are meant to fill; no letterbox bands unless that was the chosen strategy, and then the bands carry the app's background rather than black.
- Text is not truncated where it wasn't on a regular iPhone; no overlapping labels.
- Transitions between fold states do not leave stale layout (e.g. a phone-width column stuck on the inner screen, or an inner layout squeezed onto the outer screen). A screen with a different inner layout (rail, two panes, side panel, popover) returns to its phone layout on the outer screen.
- Scroll positions, selection, input state and playing media survive a fold/unfold.

## Evidence
- Screenshot folder for this validation: `<path>` (same outer/ inner/ inner_portrait/ layout as the input)
- Build: `<scheme/config>`, source state `<commit sha or "uncommitted working tree">`
