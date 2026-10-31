# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A Claude Code plugin **marketplace** (name: `mobile-compat`, catalog in `.claude-plugin/marketplace.json`) of targeted fix plugins for existing mobile apps — **one plugin per fix**. Each fix brings an app in line with one specific platform or device change: a new form factor, an OS behaviour change, a store/SDK requirement, an OEM quirk. There is no buildable app: the content is `SKILL.md` prompts, reference docs, scripts executed in place from the installed skill directory, and helper source that gets adapted into target projects. There are no build, lint, or test commands.

```
.claude-plugin/marketplace.json            lists every plugin explicitly (plugins are not auto-discovered)
plugins/<fix>/.claude-plugin/plugin.json   name, version, description
plugins/<fix>/skills/<fix>/SKILL.md        + references/ scripts/ assets/
```

### Verifying a change

The only end-to-end check is loading the plugin from a real target project and invoking the skill:

```bash
cd /path/to/an-app && claude --plugin-dir /path/to/mobile-compat-skills/plugins/<fix>
```

To test the marketplace entry itself: `/plugin marketplace add /path/to/mobile-compat-skills`, then `/plugin install <fix>@mobile-compat`.

Root `analysis_options.yaml` excludes `**/*` from the Dart analyzer **on purpose**: helper `.dart` files import Flutter packages this repo doesn't depend on (there is no `pubspec.yaml`). They are prompt material, not compilable code — don't "fix" them to satisfy an analyzer.

## What belongs here

A fix is **specific**: one externally caused problem with a known cure, not general app-building guidance (stack-specific workflows such as feature development or build/deploy live in their own repos). A fix may cover several stacks — `iphone-duo-ui-fix` handles Swift and Flutter — with per-stack material in separate references so only the relevant one is read.

## Conventions for a fix

Modelled on `iphone-duo-ui-fix`; follow them unless a fix has a reason not to.

- **Gated workflow**: toolchain + stack detection first; evidence (screenshots, logs) triaged and mapped to code; fix proposals built on the mechanisms the repo already has; a plan that waits for explicit approval before any source edit; implementation; validation by the caller or by Claude; optional review by fresh subagents.
- **Never touches git** — no branches, staging or commits; branch/dirty state is only reported. The skill writes nothing of its own into the target repo beyond the approved changes.
- **Facts in one reference**: device numbers, versions and API names live in a single facts file read once per run; SKILL.md forbids quoting them from memory.
- **Dated baseline + staleness check**: a dated survey of tooling/versions in `references/`, mirrored by constants in the detection script, which prints `survey=current|stale`. A refresh updates the survey file and the script constants together.
- **Scripts**: read-only, non-interactive, `KEY=VALUE` lines on stdout, exit codes documented in the header comment, macOS bash 3.2 compatible, stdlib-only Python. SKILL.md marks them "run, don't read".
- **Project-agnostic**: never hardcode a target project's names, paths or rules.
- **`description:` frontmatter is the auto-trigger**: list the phrases and situations users actually say; stay under 1024 characters.

## Plugin rules

- **Self-contained**: an installed plugin is copied to the plugin cache on its own, so nothing may reference files outside its plugin folder (no `../`). Shared scripts are duplicated per plugin.
- **Bump `version` in the plugin's `plugin.json` on every change**, baseline refreshes included — installed users don't receive changes otherwise. The version lives in `plugin.json` only, not in the marketplace entry.
- **Adding a fix**: create `plugins/<fix>/` with `.claude-plugin/plugin.json` and `skills/<fix>/`, add an entry to `marketplace.json`, add a row to README's plugin table.
- **Don't rename** the marketplace (`mobile-compat`) or a published plugin: installs reference `<plugin>@mobile-compat`.

## Cross-file contracts — `iphone-duo-ui-fix`

- `references/baseline-survey.md` ↔ the survey block of `scripts/detect_stack.sh` (`BASELINE_DATE`, `BASELINE_XCODE_LINES`, `BASELINE_FLUTTER_LINES`, `BASELINE_KNOWN_PKGS`) and its `FOLD_PKGS` list — update together.
- Display sizes in `references/duo-device-facts.md` ↔ the expected sizes in `scripts/inventory_screenshots.py` ↔ SKILL.md Phase 2 step 1.
- Screenshot folder names (`outer/`, `inner/` with alias `inner_landscape/`, `inner_portrait/`) are shared by SKILL.md, `duo-device-facts.md`, `validation-on-device.md`, `inventory_screenshots.py`, `capture_duo_screens.sh`, `assets/screenshot-manifest-template.yaml` and `assets/validation-checklist.md` — a rename touches all of them.
