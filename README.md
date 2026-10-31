# mobile-compat

A Claude Code plugin **marketplace** of targeted fixes for existing mobile apps. Each plugin handles one specific platform or device change that breaks (or will break) an app: a new form factor, an OS behaviour change, a new store or SDK requirement, a device/OEM quirk.

## Plugins

| Plugin | Fixes | Stacks |
|---|---|---|
| `iphone-duo-ui-fix` | UI/layout on iPhone Duo's inner and outer displays, driven by screenshots of broken screens | Swift (SwiftUI/UIKit), Flutter |

## Installation

Prerequisite: [Claude Code](https://claude.com/claude-code) installed and working.

```
/plugin marketplace add teaualune/mobile-compat-skills
/plugin install iphone-duo-ui-fix@mobile-compat
```

Install only the fixes you need; each plugin is versioned and updated on its own (`/plugin update iphone-duo-ui-fix`). Skills trigger automatically when you describe the problem, or invoke them by namespaced name, e.g. `/iphone-duo-ui-fix:iphone-duo-ui-fix`.

To try a local checkout without installing anything:

```bash
cd /path/to/your-app && claude --plugin-dir /path/to/mobile-compat-skills/plugins/iphone-duo-ui-fix
```

Without the plugin system, copy a skill folder (`plugins/<plugin>/skills/<skill>/`) into a project's `.claude/skills/` or into `~/.claude/skills/`.

## How a fix works

Every fix follows the same gated shape: check the toolchain and detect the stack → triage the evidence (screenshots, logs) → propose fixes built on what the repo already has → write a plan and wait for approval → implement → validate → optional review. Fixes never create branches, stage or commit; that stays with you.

Fix knowledge goes stale as platforms move. Each fix ships a dated baseline survey and checks the project against it; when the baseline is stale, it runs a fresh survey before planning.

## License

[WTFPL](LICENSE)
