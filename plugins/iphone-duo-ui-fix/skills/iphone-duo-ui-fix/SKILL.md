---
name: iphone-duo-ui-fix
description: "Fix an existing mobile app's UI/layout for iPhone Duo (Apple's foldable iPhone, inner + outer display), from screenshots of broken screens, screens with no screenshots, or 'screens like this one'. Use this whenever someone in a native iOS (Swift/SwiftUI/UIKit) or Flutter-with-ios repo mentions iPhone Duo, iPhone Fold, the foldable iPhone, inner/outer screen, cover display, hinge, fold state, 'looks wrong when unfolded', a letterboxed or centered app on the big screen, asks how a screen should look unfolded, or hands over inner/outer screenshot folders — even if they just say 'make it look right on the new iPhone'. Gated workflow: Xcode 27.1 gate, stack detection and a dated tooling survey; defects seen in screenshots or predicted from code; fixes built on the repo's own mechanisms, with designer layout patterns when the caller has none; an approval-gated plan; implementation; validation on a Duo or its simulator; optional subagent review. Never touches git. Safe to re-run for more screens."
---

# iPhone Duo UI fix

Turns "my app looks broken on iPhone Duo" — with screenshots, with a list of screens that have none, or with "everything built like this one" — into reviewed, validated code changes. It is gated: the caller approves the plan before any code changes, decides who validates, and opts into review. Treat every pause as a real stop — ask, then wait.

**The device in three lines.** The **outer** display (device closed) is a wider, shorter phone (466 × 678 pt, compact width) with a one-sided 84 pt status rail. The **inner** display is nearly square and *regular × regular* like an iPad. Opened, it is in **landscape** — a wide 951 × 669 pt window where tab bars stretch, heroes crop, columns go too wide and buttons fall off. Rotated, it is in **portrait** — a tall 669 × 951 pt window that looks like a normal iPhone and is rarely broken. Screenshot folders follow these terms: `outer/`, `inner/` (landscape; `inner_landscape/` is accepted as an alias), `inner_portrait/`. **The window an app gets is decided by the SDK it was linked against, not by any plist key**: Xcode ≤ 26 builds run centered in a black frame ("compatibility mode"); only an iOS 27.1 SDK build goes edge to edge. Everything numeric is in `references/duo-device-facts.md` — read it once per run, never quote numbers from memory.

Order is stack first, screens second: a proposal that says "wrap this in the adaptive helper the repo already has" is worth more than "make the tab bar narrower", and you can only write it once you know the repo.

The skill writes nothing of its own into the repo. The proposal table, the plan and any fresh survey live in the conversation; the caller decides where (if anywhere) to file them. Re-runs on the same app need no special handling — the scope confirmed in Phase 2 defines each run, and anything an earlier run left in the code is found in Phase 1 like any other mechanism.

Keep a task list for the phases; the caller may step away between pauses.

---

## Phase 1 — Stack detection and tooling survey

**Goal:** the toolchain can target Duo, and you know exactly which mechanisms the fixes can be built on.

1. **Detect.** `scripts/detect_stack.sh <repo-root>`. It prints stack (native/Flutter, SwiftUI/UIKit/mixed), Info.plist location or synthesized keys, deployment target, red-flag counts (`UIScreen.main`, `setPreferredOrientations`, window-size reads), foldable packages in `pubspec.yaml`, existing Duo helpers (`duo_helpers=`), git branch/dirtiness (reported only), and `survey=current|stale` with reasons.
2. **Xcode gate.** `scripts/check_xcode.sh` on the Mac that builds the project (device-bridge shell in a cloud session; otherwise ask the caller to run it and paste the output). Needs `status=ok` — Xcode ≥ 27.1 (27A9275+, Swift 6.4, iOS 27.1 SDK). Xcode 27.0 has no Duo simulator and leaves a black rail; older puts the app in compatibility mode. If it fails, stop and say what to update; do not work around it with older APIs. With a built `.app` at hand, `scripts/check_app_sdk.sh <App.app>` confirms the binary really links 27.1 (a stale `DEVELOPER_DIR` passes the first check and fails this one).
3. **Mechanisms.** Read the stack playbook — `references/swift-playbook.md` or `references/flutter-playbook.md` (strategy, symptom table, layout-pattern mechanisms; the helper code lives in `assets/helpers/` and is read only when implementing). Then list what the repo already has: a background/theme host, a responsive helper or breakpoints, a tab/scaffold wrapper, scene delegate, size-class plumbing, and any iPad/tablet variant of a screen (that screen's regular-width layout already exists — gate it on width). If `duo_helpers=` names existing Duo work, read it and treat its choices (column width, breakpoints, which screens are adaptive vs centered) as established conventions: reuse that helper rather than adding a second one, and present any change to it as a change to an existing decision. Two findings always go into the plan regardless of screenshots: a missing scene lifecycle (`UIApplicationSceneManifest` absent / AppDelegate-only window — iOS 27 SDK builds fail to launch without it; stock Flutter AppDelegates auto-migrate on Flutter ≥ 3.41) and `UIRequiresFullScreen` (still honoured on Duo: it scales and pillarboxes the app).
4. **Survey.** `references/baseline-survey.md` is a dated snapshot of Duo-capable Flutter packages, Flutter framework support and the Swift APIs. `detect_stack.sh` already compared the project against it:
   - `survey=current` → tell the caller the baseline is current enough and **ask whether to skip a fresh survey**. Default to skipping. You do not need to open the file unless a Flutter package decision comes up (then read its package table).
   - `survey=stale` → read the baseline file, run its fresh-survey checklist (pub.dev, flutter/flutter issues, Apple release notes), and present the result in the conversation in the same shape (what changed first, then the tables). The packages/versions the plan relies on go into the plan's Dependencies section — that is the only place they persist.
   - **Flutter with no Duo tooling:** `MediaQuery.displayFeatures` is still empty on iOS, so decide what the fixes need — width-based layout only (no package: `LayoutBuilder` + the `DuoLayout` helper) versus fold/hinge geometry or navigation in the vertical bar (a package from the survey). Propose with one line of reason per package and get agreement before it enters a plan.
5. Summarize in a few lines: stack, versions, Xcode status, mechanisms, survey decision. No pause unless the gate failed or a package choice needs an answer.

---

## Phase 2 — Scope, evidence and fix proposals

**Goal:** a table of every screen in scope — screenshot or not — mapped to the code that draws it, its defects (seen, or predicted from code), and an agreed fix direction expressed with Phase 1's mechanisms.

Screens without screenshots are normal (no time, no device, "it's the same as that one"); never block on them — their defects come from the code.

1. **Scope.** Ask in one question where the screenshots are (if not given) and which screens to fix that have none — by name, route, file, or "like <screen>".
   - `python3 scripts/inventory_screenshots.py <root>` lists `outer/`, `inner/` (`inner_landscape/` accepted as an alias) and `inner_portrait/` files, their real display (outer 1398 × 2034, inner landscape 2853 × 2007, inner portrait 2007 × 2853 px; MISMATCH with the right folder when one is misfiled), hints from `manifest.yaml` / `manifest.json` / sidecar `.md` (template: `assets/screenshot-manifest-template.yaml`), and manifest entries keyed by a screen name — screens without a screenshot, `like:` naming the screen they are built like. Fold in screens and hints given elsewhere. Mention mismatches once.
   - Nothing named at all ("just fix the app"): `python3 scripts/scan_layout_code.py <repo-root>` lists files, riskiest first, with their layout patterns. Propose a first batch — navigation shell, top-level tab screens, the riskiest screens, grouped by shared containers — small enough to validate in one pass.
2. **Screenshots.** Open every one with the Read tool. Write concrete defects per file ("tab labels 300 pt from their icons", "hero cropped to a vertical band, black both sides", "Continue button below the visible area"). Vague descriptions produce vague fixes. A phone-shaped box in a black frame is compatibility mode — the fix is the Xcode 27.1 build from Phase 1; say so and ask for re-captured screenshots before proposing layout changes.
3. **Map every screen to code**, in order of reliability: the caller's `screen:`/hint → visible strings grepped across sources and localization files (`.strings`, `.xcstrings`, `.arb`) → for a screen without a screenshot, its name or route matched against type names, route tables and localization keys → navigation structure (tab index, routes) → ask the caller, batching everything unmapped into one question.
4. **Siblings.** For each mapped screen (one per group sharing a root cause is enough), `python3 scripts/scan_layout_code.py <repo-root> --like <file>` ranks screens that share its project-defined widgets and types. Open the top few; those really built the same way are proposed for the scope as "like <screen>" — they join only when the caller confirms at the pause.
5. **Screens without a screenshot.** `python3 scripts/scan_layout_code.py <repo-root> <files>` prints `file:line` hits, each with the defect it predicts, and the screen's layout patterns. Then read the screen and the containers it sits in (scaffold, base class, shared widgets), using the playbook's symptom table backwards — cause in code → what it shows on inner landscape, outer and inner portrait. Write predicted defects as concretely as seen ones, each with its `file:line`, marked *predicted*; a hit is where to look, not a verdict. A screen "like X" inherits X's seen defects only where the code really is shared; list where it diverges (a sticky button or a sheet X lacks). Code reading is the default; if the Xcode gate passed and the app launches, offer in one line at the pause to capture these screens on the simulator first (`references/validation-on-device.md`) — worth it when predictions are shaky or most of the scope is unseen.
6. **Fix direction per screen.** With a hint: follow it and say how, using Phase 1's mechanisms. Without one, or with a vague one ("make it look nice"): name the layout patterns the screen contains (`references/layout-patterns.md`; the scanner's `patterns=` is a start) and propose each pattern's regular-width form with the playbook's mechanism, described as what the open phone will show. Every proposal meets the baseline — **every feature stays usable** (nothing interactive squashed, clipped or off screen) and **no visual breaks** (backgrounds and hero art fill their intended area; no accidental letterbox bands; nothing in the hinge region). Prefer the adaptive strategy; fall back to the centered column where the design cannot stretch gracefully — that fallback is legitimate (it is what pre-27 builds look like) only when the non-interactive background stretches edge to edge and just the content is centered. With a *restructure*-effort pattern, also offer its baseline alternative so the caller can choose by effort. Group screens sharing a root cause; say which unseen screens a shared fix also covers.
7. **Pause.** Present the table (screen → evidence: screenshot / predicted / like X → defects → fix: pattern + mechanism → effort → hint honoured or proposed) and the proposed siblings, and ask the caller to confirm or adjust. If they are clearly absent, take hinted directions as approved, mark the rest "proposed, unconfirmed", leave proposed siblings out, and continue — the plan pause is a second chance.

The scope is what the caller confirms here. Note other screens likely affected, but leave them for a later run unless the caller pulls them in or a shared fix covers them for free.

---

## Phase 3 — Plan, pause, implement

1. Write the plan as a message with these sections: **Inputs** (screenshots; screens without one and how their defects were found; stack/versions, Xcode, survey used, branch + dirty state at start); **Strategy** (one paragraph: what inner and outer will look like, which screens adaptive vs centered); **Dependencies** (packages/APIs with versions and reasons; Info.plist / build-setting changes); **Screens affected** (table: screen, evidence, problem, fix + pattern, files); **Shared changes** (helpers, hosts, delegates — reuse `assets/helpers/*` as the starting point, adapted to the codebase's style); **File touch list** (N new / M modified, one line each); **Out of scope**; **Validation plan** (every screen without a screenshot is checked on all three displays — nothing on it has been seen yet); **Open questions**. Name playbook patterns so a reviewer can look them up. If the caller wants the plan in a particular place (their spec folder, a ticket), write it there in their format; otherwise it stays in the conversation.
2. **Pause.** Ask for approval with AskUserQuestion (*Approve · Change something · Discuss a specific screen*). Iterate until approved. Do not touch source files before approval.
3. Implement: shared changes first, then screen by screen; minimal, idiomatic edits; run the project's build/lint/test step after each cohesive change (`xcodebuild build`, `flutter analyze`, `flutter test`). If the plan turns out wrong, say so and ask before deviating in scope or dependencies; small tactical deviations go in the hand-back summary.

---

## Phase 4 — Validation

1. Ask (AskUserQuestion) whether **they** check the screens or **you** run the app on a physical Duo / Device Hub simulator.
2. They validate: give them `assets/validation-checklist.md` pre-filled with the plan's screens and their *Before* evidence; phase complete; offer to fix what they find.
3. You validate: read `references/validation-on-device.md` now (unless Phase 2 already did). Confirm the build links 27.1 (`check_app_sdk.sh`), create/boot the Duo simulator, install, drive to each screen, capture per display with `scripts/capture_duo_screens.sh`, change pose while on the screen (no `simctl` fold command — Device Hub's pose buttons via desktop control, or a community CLI the caller agrees to install). Judge every capture with the Read tool against the checklist. Present before/after pairs; a screen that had no screenshot has only an after — grade it on the checklist and say which predicted defects were real and are fixed, and what was not predicted. Ask whether they are satisfied, want another iteration on a named screen, or want to stop. Loop on that answer.

---

## Phase 5 (optional) — Code review

Ask whether the caller wants a separate review. If yes, spawn subagents that have not seen the implementation, one per concern — layout correctness across displays and fold transitions; regression risk on regular iPhones/iPad; code quality and idiom — each given the changes (read-only `git diff` or the touch list) and the plan text. Template: `assets/review-prompt.md`. De-duplicate, triage fix-now / later / disagree, discuss, apply agreed fixes, re-run build/tests.

---

## Done — hand back

Branching, commits and pushes are the caller's; create no branches, stage or commit nothing. End with: what changed (touch list + deviations), what is left for them (self-validation, deferred review findings, screens noticed but not touched), and the branch/dirty state `detect_stack.sh` reported at the start so they know what their diff contains.

## Working notes
- The caller may be a designer or PM; explain trade-offs as what the screen will look like, not framework internals, unless asked.
- Fix the cause (a width assumption, a root container) over patching each screen; it is what makes the next run cheap.
- A predicted defect is a claim about code, not a sighting: keep calling it predicted until a capture confirms it.
- A screenshot showing a non-Duo bug: mention it, leave it out of the plan unless the caller pulls it in.

## Files
| Path | Read when |
|---|---|
| `references/duo-device-facts.md` | once per run, at the start |
| `references/swift-playbook.md` / `flutter-playbook.md` | Phase 1 step 3 (the one for the stack) |
| `references/baseline-survey.md` | only if `survey=stale` or a Flutter package decision is needed |
| `references/layout-patterns.md` | Phase 2 step 6, when a screen has no direction from the caller |
| `references/validation-on-device.md` | Phase 4 if you validate; Phase 2 if you capture screens that have no screenshot |
| `assets/helpers/duo_layout.dart`, `DuoCenteredColumn.swift`, `DuoColumnContainerViewController.swift` | Phase 3 implementation, the one the plan uses |
| `assets/screenshot-manifest-template.yaml` | share with the caller if their screenshots have no hints or they list screens without one |
| `assets/validation-checklist.md`, `assets/review-prompt.md` | Phase 4 / Phase 5 |
| `scripts/detect_stack.sh`, `check_xcode.sh`, `check_app_sdk.sh`, `inventory_screenshots.py`, `scan_layout_code.py`, `capture_duo_screens.sh` | run, don't read |
