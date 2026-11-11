# Layout patterns — compact → regular

The fixes to suggest for a screen when the caller hasn't said how they want it fixed. Source: a UI/UX designer's review of how phone layouts should change on a foldable's open display (2026-11), adapted to iPhone Duo. Stack-neutral: the code mechanism for each pattern is in the stack playbook's "Layout patterns" table. Width classes and every number live in `duo-device-facts.md`; on Duo the outer display is *compact*, inner portrait *medium*, inner landscape *expanded*, and a Split View pane *compact*.

## Using them
- **Name every pattern on the screen.** A screen usually holds several (a feed, a primary button, a filter sheet). Propose each pattern's regular form and describe the result as what the open phone shows ("orders stay listed on the left; the tapped order opens on the right").
- **The compact form stays** on the outer display and on regular iPhones. The regular form starts at the width class in *From* and applies at every wider class.
- **Branch on the width the screen gets**, not on size class or device: the inner display is regular × regular in both orientations, but a Split View pane is regular at about half the width.
- **Native: system containers first.** `TabView`, `NavigationSplitView`, sheets and their UIKit counterparts already switch form on Duo. Propose the system container over a hand-built equivalent, and accept where the system puts things (tab bars go into the trailing vertical bar, not a leading rail).
- **An existing tablet layout is the regular form.** If the repo already has an iPad/tablet variant of the screen (gated on idiom or a tablet flag), propose gating it on width instead of designing a new one.
- **Effort.** *layout* = a width branch inside the screen; *restructure* = navigation, presentation or state that must survive switching between the two forms. With every *restructure* proposal also give its *baseline* alternative (below) — the minimum that meets the skill's baseline — so the caller can choose by effort.
- The caller's hint always overrides this file.

## The patterns

| id | Element | Compact (outer, regular iPhones) | Regular (inner display) | From | Effort |
|---|---|---|---|---|---|
| `global-nav` | Global navigation | Horizontal bottom tab bar (thumb zone) | Vertical rail or sidebar on a side edge, where both thumbs naturally rest | medium | layout |
| `list-detail` | List & detail | One full-screen page; a tap pushes the next level in | List pane + detail pane side by side (two-pane / split view) | expanded | restructure |
| `cards-feed` | Cards & feeds | One column of full-width cards | 2–3 equal columns in a responsive grid; cards keep their proportions | medium (2), expanded (3) | layout |
| `long-form` | Article / long text | Text runs the full screen width | Reading width capped and centered; or the side margins carry a table of contents and supporting info | medium (cap), expanded (side panels) | layout |
| `bottom-sheet` | Bottom sheet | Full-width panel sliding up from the bottom | Popover anchored to the control that opened it, or a fixed-width dialog in the center | medium | layout, per call site |
| `primary-cta` | Primary action button | Full-width button stuck to the bottom edge (sticky bottom bar) | No full-width stretch: a fixed-width button at the bottom-trailing corner, or a local button attached to the card or section it completes | medium | layout |
| `form` | Form fields | Label above the field, fields stacked downward | Label leading + field trailing on one row; or two columns of grouped cards | medium (rows), expanded (two columns) | layout |
| `media` | Media & live streaming | 16:9 player on top, chat / comments below | Large player leading + a separate vertical chat / menu column trailing | expanded | restructure |
| `canvas-tools` | Creation canvas & toolbars | Tools tucked in a bottom drawer or a secondary menu | Vertical inspector panel fixed to the trailing (or leading) edge | expanded | restructure |
| `flex-mode` | Half-folded UI (the designer's "tabletop / flex mode"; Apple: *partially folded*) | n/a — no fold | Top half shows the content or viewfinder; bottom half becomes a control panel / touch area; nothing on the fold | inner display, partially folded | restructure |

## Duo notes and baseline alternatives

**`global-nav`** — Rail items need icon + label. Native: the system moves `TabView` / `UITabBarController` into the trailing vertical bar (sidebar placement optional); don't hand-build a leading rail that competes with it. Flutter draws its own bars: a leading rail. *Baseline:* the bottom bar centered in a phone-width column.

**`list-detail`** — Two panes at expanded only; inner portrait and Split View keep one pane. Keep the selection in state: folding with an item open shows that item full screen; unfolding shows it selected in the detail pane. An empty detail pane gets a placeholder, never a blank. *Baseline:* the list in a centered column, push navigation unchanged.

**`cards-feed`** — The column count comes from the width; card height follows card width, never stretched. If the compact design is one column, it stays one column on the outer display. *Baseline:* the same — this one is cheap.

**`long-form`** — Side panels carry only content the screen already has (chapters, related links, metadata); don't invent content. *Baseline:* the capped reading width.

**`bottom-sheet`** — Popover for short choices tied to a control (menus, pickers, filters); centered dialog for inputs and confirmations. Native `.sheet` / form sheets already center on the inner display — the work is custom-drawn sheets. Partially folded, a centered dialog straddles the fold; one with inputs belongs on one side. *Baseline:* the sheet's width capped.

**`primary-cta`** — The trailing corner mirrors in right-to-left languages. Clear the trailing safe area and any vertical bar, and keep the button out of the fold band. The outer display keeps the full-width sticky bar. *Baseline:* the button's width capped.

**`form`** — Two columns only for independent groups (shipping / billing), each keeping its own Next / focus order. The keyboard covers much of the inner landscape's height: the focused field must stay visible. *Baseline:* the field column capped and centered.

**`media`** — Inner portrait stays stacked (the tall window fits player + chat). One player instance across the switch: playback must not restart or lose its position on fold/unfold. *Baseline:* player sized by aspect ratio inside a max width, chat below.

**`canvas-tools`** — Tool and selection state survive switching between panel and drawer. *Baseline:* the drawer kept, its width capped.

**`flex-mode`** — Held in an L-shape (inner portrait, fold horizontal): content above, controls below. Held like a book (inner landscape, fold vertical): content on one side, controls on the other. Lay out from the `.division` reserved region, never from the hinge angle or a hard-coded fold position (Apple: the hinge is for effects, not layout). Fits camera, video-call, playback and creation screens; propose it there as an optional extra, never as a screen's only fix. Flutter needs a fold package (SKILL.md Phase 1 step 4). *Baseline:* nothing extra — primary controls stay out of the fold band.
