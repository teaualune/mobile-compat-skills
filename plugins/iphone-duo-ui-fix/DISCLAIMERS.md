# Trademark & third-party disclaimers

Informational notices — not part of the MIT License in [`LICENSE`](LICENSE).

"Claude", "Claude Code", and "Anthropic" are trademarks of Anthropic,
PBC. This project is an independent, community-made skill for use with
Claude Code. It is not affiliated with, sponsored by, or endorsed by
Anthropic. The license applies only to the contents of this plugin and
grants no rights to the "Claude" or "Anthropic" names, trademarks, or
products. References to Claude and Claude Code serve solely to identify
the tool this skill is designed to run with.

"Apple", "iPhone", "iPad", "iOS", "macOS", "Xcode", "Simulator",
"Swift", "SwiftUI", and "UIKit" are trademarks of Apple Inc., and
"iPhone Duo" names an Apple device. "Flutter", "Dart", "Material", and
"Android" are trademarks of Google LLC. This skill invokes publicly
documented first-party tooling — `xcodebuild`, `xcrun`, `simctl` and
`devicectl`, the Xcode simulators and Device Hub — to build, run and
capture the user's own app. It is not affiliated with, sponsored by, or endorsed by Apple or
Google; the license grants no rights to those names, trademarks, or
products, and those names appear solely to identify the devices,
platforms and tools the skill targets. Device facts in the skill's
references come from public sources and may change.

The command-line tools and packages referenced in this plugin —
including but not limited to fvm, Python, `sips`, and the state
management packages a target app may use — are the property of their
respective authors and are governed by their own licenses. This plugin
does not bundle or redistribute any of them; their names appear solely
to identify the technologies the skill detects or runs. No affiliation
with or endorsement by any author is implied. The optional community
CLIs the device checks can use (`hinge`, `duoctl`, `devicehubctl`) send
the private, undocumented hinge event Device Hub uses; they are
third-party tools the user installs, unsupported by Apple, and may stop
working with any Xcode update.

**No warranty / operational risk.** The material in this plugin is
provided "as is", without warranty of any kind. After the user approves
a plan, the skill edits the app's UI code and may add helper source
files to it, and it may build and run the app on a simulator or a
device to capture and check screens. It never changes git state (it
only reads the branch and working-tree status), so the changes stay in
the working tree for the user to review. Review every change
before keeping it, and validate the result on real hardware before
shipping it. The authors accept no liability for any code change,
layout regression, device state, or release consequence arising from
its use.
