---
name: iphone-duo-ui-fix
description: "Fix an existing mobile app's UI/layout for iPhone Duo (Apple's foldable iPhone with an inner and outer display), driven by screenshots of broken screens. Use this whenever someone in a native iOS (Swift/SwiftUI/UIKit) or Flutter-with-ios repo mentions iPhone Duo, iPhone Fold, the foldable iPhone, inner/outer screen, cover display, hinge, fold state, 'looks wrong when unfolded', a letterboxed or centered app on the big screen, or hands over inner/outer screenshot folders — even if they just say 'make it look right on the new iPhone'. Gated workflow: Xcode 27.1 gate and stack detection (with a dated baseline survey of Duo-ready Flutter/Swift tooling), screenshot triage and fix proposals built on what the repo already has, a plan that waits for approval, implementation, validation on a physical Duo or the Device Hub simulator, optional subagent code review. Never touches git. Safe to re-run for more screens."
---

# iPhone Duo UI fix

Turns "here are screenshots of my app looking broken on iPhone Duo" into reviewed, validated code changes. It is gated: the caller approves the plan before any code changes, decides who validates, and opts into review. Treat every pause as a real stop — ask, then wait.

**The device in three lines.** The **outer** display (device closed) is a wider, shorter phone (466 × 678 pt, compact width) with a one-sided 84 pt status rail. The **inner** display is nearly square and *regular × regular* like an iPad. Opened, it is in **landscape** — a wide 951 × 669 pt window where tab bars stretch, heroes crop, columns go too wide and buttons fall off. Rotated, it is in **portrait** — a tall 669 × 951 pt window that looks like a normal iPhone and is rarely broken. Screenshot folders follow these terms: `outer/`, `inner/` (landscape; `inner_landscape/` is accepted as an alias), `inner_portrait/`. **The window an app gets is decided by the SDK it was linked against, not by any plist key**: Xcode ≤ 26 builds run centered in a black frame ("compatibility mode"); only an iOS 27.1 SDK build goes edge to edge. Everything numeric is in `references/duo-device-facts.md` — read it once per run, never quote numbers from memory.

Order is stack first, screenshots second: a proposal that says "wrap this in the adaptive helper the repo already has" is worth more than "make the tab bar narrower", and you can only write it once you know the repo.

The skill writes nothing of its own into the repo. The proposal table, the plan and any fresh survey live in the conversation; the caller decides where (if anywhere) to file them. Re-runs on the same app need no special handling — the screenshots define each run's scope, and anything an earlier run left in the code is found in Phase 1 like any other mechanism.

Keep a task list for the phases; the caller may step away between pauses.

---

## Phase 1 — Stack detection and tooling survey

**Goal:** the toolchain can target Duo, and you know exactly which mechanisms the fixes can be built on.

1. **Detect.** `scripts/detect_stack.sh <repo-root>`. It prints stack (native/Flutter, SwiftUI/UIKit/mixed), Info.plist location or synthesized keys, deployment target, red-flag counts (`UIScreen.main`, `setPreferredOrientations`, window-size reads), foldable packages in `pubspec.yaml`, existing Duo helpers (`duo_helpers=`), git branch/dirtiness (reported only), and `survey=current|stale` with reasons.
2. **Xcode gate.** `scripts/check_xcode.sh` on the Mac that builds the project (device-bridge shell in a cloud session; otherwise ask the caller to run it and paste the output). Needs `status=ok` — Xcode ≥ 27.1 (27A9275+, Swift 6.4, iOS 27.1 SDK). Xcode 27.0 has no Duo simulator and leaves a black rail; older puts the app in compatibility mode. If it fails, stop and say what to update; do not work around it with older APIs. With a built `.app` at hand, `scripts/check_app_sdk.sh <App.app>` confirms the binary really links 27.1 (a stale `DEVELOPER_DIR` passes the first check and fails this one).
3. **Mechanisms.** Read the stack playbook — `references/swift-playbook.md` or `references/flutter-playbook.md` (strategy + symptom table; the helper code lives in `assets/helpers/` and is read only when implementing). Then list what the repo already has: a background/theme host, a responsive helper or breakpoints, a tab/scaffold wrapper, scene delegate, size-class plumbing. If `duo_helpers=` names existing Duo work, read it and treat its choices (column width, breakpoints, which screens are adaptive vs centered) as established conventions: reuse that helper rather than adding a second one, and present any change to it as a change to an existing decision. Two findings always go into the plan regardless of screenshots: a missing scene lifecycle (`UIApplicationSceneManifest` absent / AppDelegate-only window — iOS 27 SDK builds fail to launch without it; stock Flutter AppDelegates auto-migrate on Flutter ≥ 3.41) and `UIRequiresFullScreen` (still honoured on Duo: it scales and pillarboxes the app).
4. **Survey.** `references/baseline-survey.md` is a dated snapshot of Duo-capable Flutter packages, Flutter framework support and the Swift APIs. `detect_stack.sh` already compared the project against it:
   - `survey=current` → tell the caller the baseline is current enough and **ask whether to skip a fresh survey**. Default to skipping. You do not need to open the file unless a Flutter package decision comes up (then read its package table).
   - `survey=stale` → read the baseline file, run its fresh-survey checklist (pub.dev, flutter/flutter issues, Apple release notes), and present the result in the conversation in the same shape (what changed first, then the tables). The packages/versions the plan relies on go into the plan's Dependencies section — that is the only place they persist.
   - **Flutter with no Duo tooling:** `MediaQuery.displayFeatures` is still empty on iOS, so decide what the fixes need — width-based layout only (no package: `LayoutBuilder` + the `DuoLayout` helper) versus fold/hinge geometry or navigation in the vertical bar (a package from the survey). Propose with one line of reason per package and get agreement before it enters a plan.
5. Summarize in a few lines: stack, versions, Xcode status, mechanisms, survey decision. No pause unless the gate failed or a package choice needs an answer.

---

## Phase 2 — Screenshots and fix proposals

**Goal:** a table mapping every screenshot to the code that draws it, the defects it shows, and an agreed fix direction expressed with Phase 1's mechanisms.

1. Ask where the screenshots are if not given. `python3 scripts/inventory_screenshots.py <root>` lists `outer/`, `inner/` (`inner_landscape/` accepted as an alias) and `inner_portrait/` files, their real display (outer 1398 × 2034, inner landscape 2853 × 2007, inner portrait 2007 × 2853 px; MISMATCH with the right folder when one is misfiled), and hints from `manifest.yaml` / `manifest.json` / sidecar `.md` (template: `assets/screenshot-manifest-template.yaml`). Fold in hints given elsewhere. Mention mismatches once.
2. Open every screenshot with the Read tool. Write concrete defects per file ("tab labels 300 pt from their icons", "hero cropped to a vertical band, black both sides", "Continue button below the visible area"). Vague descriptions produce vague fixes. A phone-shaped box in a black frame is compatibility mode — the fix is the Xcode 27.1 build from Phase 1; say so and ask for re-captured screenshots before proposing layout changes.
3. Map each screenshot to code, in order of reliability: the caller's `screen:`/hint → visible strings grepped across sources and localization files (`.strings`, `.xcstrings`, `.arb`) → navigation structure (tab index, routes) → ask the caller, batching all unmapped files into one question.
4. Fix direction per screenshot. With a hint: follow it and say how, using Phase 1's mechanisms. Without: propose one that meets the baseline — **every feature stays usable** (nothing interactive squashed, clipped or off screen) and **no visual breaks** (backgrounds and hero art fill their intended area; no accidental letterbox bands; nothing in the hinge region). Prefer the adaptive strategy; fall back to the centered column where the design cannot stretch gracefully — that fallback is legitimate (it is what pre-27 builds look like) only when the non-interactive background stretches edge to edge and just the content is centered. Group screenshots sharing a root cause; say which unseen screens the shared fix will also cover.
5. **Pause.** Present the table (screenshot → screen → defects → fix + mechanism → hint honoured?) and ask the caller to confirm or adjust. If they are clearly absent, take hinted directions as approved, mark the rest "proposed, unconfirmed", and continue — the plan pause is a second chance.

The screenshots define the scope; note other screens likely affected, but leave them for a later run unless a shared fix covers them for free.

---

## Phase 3 — Plan, pause, implement

1. Write the plan as a message with these sections: **Inputs** (screenshots, stack/versions, Xcode, survey used, branch + dirty state at start); **Strategy** (one paragraph: what inner and outer will look like, which screens adaptive vs centered); **Dependencies** (packages/APIs with versions and reasons; Info.plist / build-setting changes); **Screens affected** (table: screenshot, screen, problem, fix, files); **Shared changes** (helpers, hosts, delegates — reuse `assets/helpers/*` as the starting point, adapted to the codebase's style); **File touch list** (N new / M modified, one line each); **Out of scope**; **Validation plan**; **Open questions**. Name playbook patterns so a reviewer can look them up. If the caller wants the plan in a particular place (their spec folder, a ticket), write it there in their format; otherwise it stays in the conversation.
2. **Pause.** Ask for approval with AskUserQuestion (*Approve · Change something · Discuss a specific screen*). Iterate until approved. Do not touch source files before approval.
3. Implement: shared changes first, then screen by screen; minimal, idiomatic edits; run the project's build/lint/test step after each cohesive change (`xcodebuild build`, `flutter analyze`, `flutter test`). If the plan turns out wrong, say so and ask before deviating in scope or dependencies; small tactical deviations go in the hand-back summary.

---

## Phase 4 — Validation

1. Ask (AskUserQuestion) whether **they** check the screens or **you** run the app on a physical Duo / Device Hub simulator.
2. They validate: give them `assets/validation-checklist.md` pre-filled with the plan's screens; phase complete; offer to fix what they find.
3. You validate: read `references/validation-on-device.md` now (not before). Confirm the build links 27.1 (`check_app_sdk.sh`), create/boot the Duo simulator, install, drive to each screen, capture per display with `scripts/capture_duo_screens.sh`, change pose while on the screen (no `simctl` fold command — Device Hub's pose buttons via desktop control, or a community CLI the caller agrees to install). Judge every capture with the Read tool against the checklist. Present before/after pairs; ask whether they are satisfied, want another iteration on a named screen, or want to stop. Loop on that answer.

---

## Phase 5 (optional) — Code review

Ask whether the caller wants a separate review. If yes, spawn subagents that have not seen the implementation, one per concern — layout correctness across displays and fold transitions; regression risk on regular iPhones/iPad; code quality and idiom — each given the changes (read-only `git diff` or the touch list) and the plan text. Template: `assets/review-prompt.md`. De-duplicate, triage fix-now / later / disagree, discuss, apply agreed fixes, re-run build/tests.

---

## Done — hand back

Branching, commits and pushes are the caller's; create no branches, stage or commit nothing. End with: what changed (touch list + deviations), what is left for them (self-validation, deferred review findings, screens noticed but not touched), and the branch/dirty state `detect_stack.sh` reported at the start so they know what their diff contains.

## Working notes
- The caller may be a designer or PM; explain trade-offs as what the screen will look like, not framework internals, unless asked.
- Fix the cause (a width assumption, a root container) over patching each screen; it is what makes the next run cheap.
- A screenshot showing a non-Duo bug: mention it, leave it out of the plan unless the caller pulls it in.

## Files
| Path | Read when |
|---|---|
| `references/duo-device-facts.md` | once per run, at the start |
| `references/swift-playbook.md` / `flutter-playbook.md` | Phase 1 step 3 (the one for the stack) |
| `references/baseline-survey.md` | only if `survey=stale` or a Flutter package decision is needed |
| `references/validation-on-device.md` | Phase 4, only if you validate |
| `assets/helpers/duo_layout.dart`, `DuoCenteredColumn.swift`, `DuoColumnContainerViewController.swift` | Phase 3 implementation, the one the plan uses |
| `assets/screenshot-manifest-template.yaml` | share with the caller if their screenshots have no hints |
| `assets/validation-checklist.md`, `assets/review-prompt.md` | Phase 4 / Phase 5 |
| `scripts/detect_stack.sh`, `check_xcode.sh`, `check_app_sdk.sh`, `inventory_screenshots.py`, `capture_duo_screens.sh` | run, don't read |
