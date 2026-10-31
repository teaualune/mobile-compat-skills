#!/usr/bin/env bash
# detect_stack.sh — figure out what kind of mobile project we are in and what
# Duo-relevant tooling it already has. Read-only; prints key=value lines.
#
# Usage:  scripts/detect_stack.sh [PROJECT_ROOT]     (default: current directory)
#
# Works on macOS bash 3.2 and Linux bash. Needs: find, grep, sed, awk, plutil (macOS, optional).

set -u
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "status=bad_root"; exit 2; }
cd "$ROOT" || exit 2

echo "project_root=${ROOT}"

# ---------- stack detection -------------------------------------------------
STACK="unknown"
if [ -f pubspec.yaml ] && grep -qE '^\s*flutter\s*:' pubspec.yaml 2>/dev/null; then
  STACK="flutter"
  [ -d ios ] && echo "flutter_ios_dir=present" || echo "flutter_ios_dir=MISSING"
else
  XCPROJ="$(find . -maxdepth 3 -name '*.xcodeproj' -not -path './Pods/*' -not -path './ios/*' 2>/dev/null | head -n 1)"
  XCWS="$(find . -maxdepth 3 -name '*.xcworkspace' -not -path '*/xcodeproj/*' -not -path './Pods/*' 2>/dev/null | head -n 1)"
  if [ -n "$XCPROJ" ] || [ -n "$XCWS" ]; then
    STACK="native_ios"
  elif [ -f Package.swift ]; then
    STACK="swift_package"
  fi
fi
echo "stack=${STACK}"

# ---------- Flutter specifics ------------------------------------------------
if [ "$STACK" = "flutter" ]; then
  # Pinned/declared Flutter + Dart versions
  if [ -f .fvmrc ]; then
    echo "fvm_flutter=$(sed -nE 's/.*"flutter"\s*:\s*"([^"]+)".*/\1/p' .fvmrc | head -n1)"
  elif [ -f .fvm/fvm_config.json ]; then
    echo "fvm_flutter=$(sed -nE 's/.*"flutterSdkVersion"\s*:\s*"([^"]+)".*/\1/p' .fvm/fvm_config.json | head -n1)"
  fi
  echo "pubspec_sdk_constraint=$(awk '/^environment:/{f=1;next} f&&/^[^ ]/{f=0} f&&/sdk:/{sub(/^[^:]*:[ ]*/,"");gsub(/[\"'"'"']/,"");print;exit}' pubspec.yaml)"
  echo "pubspec_flutter_constraint=$(awk '/^environment:/{f=1;next} f&&/^[^ ]/{f=0} f&&/flutter:/{sub(/^[^:]*:[ ]*/,"");gsub(/[\"'"'"']/,"");print;exit}' pubspec.yaml)"
  if [ -f pubspec.lock ]; then
    echo "lock_flutter_sdk=$(awk '/^sdks:/{f=1;next} f&&/flutter:/{sub(/^[^:]*:[ ]*/,"");gsub(/[\"'"'"']/,"");print;exit}' pubspec.lock)"
    echo "lock_dart_sdk=$(awk '/^sdks:/{f=1;next} f&&/dart:/{sub(/^[^:]*:[ ]*/,"");gsub(/[\"'"'"']/,"");print;exit}' pubspec.lock)"
  fi
  if command -v flutter >/dev/null 2>&1; then
    FV="$(flutter --version 2>/dev/null | head -n 1 | awk '{print $2}')"
    echo "installed_flutter=${FV:-unknown}"
    echo "installed_flutter_channel=$(flutter --version 2>/dev/null | head -n 1 | sed -nE 's/.*channel ([a-z]+).*/\1/p')"
    echo "installed_dart=$(flutter --version 2>/dev/null | sed -nE 's/.*Dart ([0-9.]+).*/\1/p' | head -n1)"
  else
    echo "installed_flutter=not_on_PATH"
  fi

  # Packages that matter for foldable / adaptive layout. Keep this list in sync
  # with references/flutter-playbook.md.
  # Duo-specific (2026): foldable unfold duo_display duo_kit fold_kit foldable_device (duo_layout = old name of unfold)
  # Generic adaptive: responsive_framework responsive_builder flutter_screenutil custom_adaptive_scaffold
  # Legacy/discontinued: dual_screen flutter_adaptive_scaffold adaptive_breakpoints
  FOLD_PKGS="foldable unfold duo_display duo_kit fold_kit foldable_device duo_layout responsive_framework responsive_builder flutter_screenutil custom_adaptive_scaffold dual_screen flutter_adaptive_scaffold adaptive_breakpoints"
  FOUND=""
  for p in $FOLD_PKGS; do
    if grep -qE "^\s*${p}\s*:" pubspec.yaml 2>/dev/null; then FOUND="${FOUND}${p} "; fi
  done
  echo "foldable_related_packages=${FOUND:-none}"

  # Any in-house platform channel or native code that already talks about folds/hinges
  NATIVE_HITS="$(grep -rlE 'hinge|fold|displayFeature|DisplayFeature|UIWindowScene|sizeClass' lib ios/Runner 2>/dev/null | grep -vE 'GeneratedPluginRegistrant|\.pbxproj' | head -n 20 | tr '\n' ' ')"
  echo "fold_related_source_files=${NATIVE_HITS:-none}"

  # UIScene migration state (mandatory for iOS 27 SDK builds; Flutter >= 3.41 auto-migrates a stock AppDelegate)
  echo "scene_delegate_file=$([ -f ios/Runner/SceneDelegate.swift ] && echo present || echo absent)"
  if [ -f ios/Runner/AppDelegate.swift ]; then
    echo "appdelegate_lines=$(wc -l < ios/Runner/AppDelegate.swift | tr -d ' ')"
    echo "appdelegate_custom=$(grep -qE 'FlutterImplicitEngineDelegate|didInitializeImplicitFlutterEngine' ios/Runner/AppDelegate.swift && echo migrated || { [ "$(wc -l < ios/Runner/AppDelegate.swift | tr -d ' ')" -gt 16 ] && echo likely_custom || echo stock; })"
  fi
  # Orientation locks are what produce letterboxing on foldables
  echo "uses_setPreferredOrientations=$(grep -rn --include='*.dart' 'setPreferredOrientations' lib 2>/dev/null | wc -l | tr -d ' ')"
  echo "uses_MediaQuery_size=$(grep -rn --include='*.dart' -E 'MediaQuery\.(of\(context\)\.size|sizeOf)' lib 2>/dev/null | wc -l | tr -d ' ')"
  echo "uses_display_size=$(grep -rn --include='*.dart' -E 'View\.of\(context\)\.display|\.displays' lib 2>/dev/null | wc -l | tr -d ' ')"

  PLIST="ios/Runner/Info.plist"
  echo "info_plist=${PLIST}"
  echo "pods=$([ -f ios/Podfile ] && echo present || echo none)"
  echo "ios_deployment_target=$(sed -nE "s/.*platform :ios, '([0-9.]+)'.*/\1/p" ios/Podfile 2>/dev/null | head -n1)"
  echo "xcodeproj=ios/Runner.xcodeproj"
fi

# ---------- Native iOS specifics ---------------------------------------------
if [ "$STACK" = "native_ios" ]; then
  echo "xcodeproj=${XCPROJ:-none}"
  echo "xcworkspace=${XCWS:-none}"
  echo "spm_package=$([ -f Package.swift ] && echo present || echo none)"
  echo "pods=$([ -f Podfile ] && echo present || echo none)"

  SWIFT_FILES="$(find . -name '*.swift' -not -path './Pods/*' -not -path './.build/*' -not -path '*/DerivedData/*' 2>/dev/null | wc -l | tr -d ' ')"
  SWIFTUI_FILES="$(grep -rl --include='*.swift' 'import SwiftUI' . 2>/dev/null | grep -v '/Pods/' | wc -l | tr -d ' ')"
  UIKIT_FILES="$(grep -rl --include='*.swift' 'import UIKit' . 2>/dev/null | grep -v '/Pods/' | wc -l | tr -d ' ')"
  OBJC_FILES="$(find . \( -name '*.m' -o -name '*.mm' \) -not -path './Pods/*' 2>/dev/null | wc -l | tr -d ' ')"
  echo "swift_files=${SWIFT_FILES}"
  echo "swiftui_files=${SWIFTUI_FILES}"
  echo "uikit_files=${UIKIT_FILES}"
  echo "objc_files=${OBJC_FILES}"
  if [ "$SWIFTUI_FILES" -gt 0 ] && [ "$UIKIT_FILES" -gt 0 ]; then echo "ui_framework=mixed"
  elif [ "$SWIFTUI_FILES" -gt 0 ]; then echo "ui_framework=swiftui"
  elif [ "$UIKIT_FILES" -gt 0 ]; then echo "ui_framework=uikit"
  else echo "ui_framework=unknown"; fi

  echo "storyboards=$(find . -name '*.storyboard' -not -path './Pods/*' 2>/dev/null | wc -l | tr -d ' ')"
  echo "xibs=$(find . -name '*.xib' -not -path './Pods/*' 2>/dev/null | wc -l | tr -d ' ')"

  # Info.plist can be a file or synthesized from INFOPLIST_KEY_* build settings.
  PLIST="$(find . -maxdepth 4 -name 'Info.plist' -not -path './Pods/*' -not -path '*Tests*' -not -path '*/.build/*' 2>/dev/null | head -n 1)"
  echo "info_plist=${PLIST:-synthesized_or_not_found}"
  PBX="$(find . -maxdepth 4 -name 'project.pbxproj' -not -path './Pods/*' 2>/dev/null | head -n 1)"
  if [ -n "$PBX" ]; then
    echo "deployment_target=$(grep -m1 -E 'IPHONEOS_DEPLOYMENT_TARGET = ' "$PBX" | sed -E 's/.*= ([0-9.]+);.*/\1/')"
    echo "swift_version_setting=$(grep -m1 -E 'SWIFT_VERSION = ' "$PBX" | sed -E 's/.*= ([0-9.]+);.*/\1/')"
    echo "targeted_device_family=$(grep -m1 -E 'TARGETED_DEVICE_FAMILY = ' "$PBX" | sed -E 's/.*= "?([0-9,]+)"?;.*/\1/')"
    echo "generate_infoplist=$(grep -m1 -E 'GENERATE_INFOPLIST_FILE = ' "$PBX" | sed -E 's/.*= ([A-Z]+);.*/\1/')"
    echo "infoplist_key_lines=$(grep -cE 'INFOPLIST_KEY_' "$PBX")"
    # Synthesized-plist equivalents of the keys that matter on Duo
    for k in UIRequiresFullScreen UIApplicationSceneManifest_Generation UISupportedInterfaceOrientations_iPhone UISupportedInterfaceOrientations; do
      v="$(grep -m1 -E "INFOPLIST_KEY_${k} = " "$PBX" | sed -E 's/.*= "?([^";]+)"?;.*/\1/')"
      echo "buildsetting_INFOPLIST_KEY_${k}=${v:-absent}"
    done
  fi

  # Red-flag API usage that breaks on a device whose window is not the full screen
  echo "uses_UIScreen_main_bounds=$(grep -rn --include='*.swift' --include='*.m' 'UIScreen.main.bounds' . 2>/dev/null | grep -v '/Pods/' | wc -l | tr -d ' ')"
  echo "uses_UIScreen_main=$(grep -rn --include='*.swift' --include='*.m' 'UIScreen.main' . 2>/dev/null | grep -v '/Pods/' | wc -l | tr -d ' ')"
  echo "uses_sizeClass=$(grep -rn --include='*.swift' -E 'horizontalSizeClass|UIUserInterfaceSizeClass' . 2>/dev/null | grep -v '/Pods/' | wc -l | tr -d ' ')"
  echo "uses_fold_apis=$(grep -rn --include='*.swift' -iE 'fold|hinge|displayFeature' . 2>/dev/null | grep -v '/Pods/' | wc -l | tr -d ' ')"
fi

# ---------- Info.plist keys that affect Duo behaviour (both stacks) ----------
# Keep in sync with references/duo-device-facts.md ("Opting in" section).
if [ -n "${PLIST:-}" ] && [ -f "${PLIST:-/nonexistent}" ]; then
  for key in UIRequiresFullScreen UIRequiresFullScreenIgnoredStartingWithVersion UISupportedInterfaceOrientations UIApplicationSceneManifest UIApplicationSupportsMultipleScenes UILaunchScreen UILaunchStoryboardName; do
    if grep -q "<key>${key}</key>" "$PLIST" 2>/dev/null; then
      val="$(grep -A1 "<key>${key}</key>" "$PLIST" | tail -n1 | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//' | head -c 120)"
      echo "plist_${key}=${val}"
    else
      echo "plist_${key}=absent"
    fi
  done
fi

# ---------- Duo helpers already in the code (from an earlier run of this skill) --
HELPERS="$(grep -rlE --include='*.swift' --include='*.dart' 'DuoLayout|DuoCenteredColumn|DuoColumnContainer|duoCenteredColumn|DuoLayoutBuilder|FoldScaffold|AdaptiveNavigationScaffold' . 2>/dev/null | grep -vE '/Pods/|/\.build/|/build/|\.symlinks' | head -n 10 | tr '\n' ' ')"
echo "duo_helpers=${HELPERS:-none}"

# ---------- is the bundled baseline survey current enough? -------------------
# Constants mirror references/baseline-survey.md; bump both when the survey is redone.
BASELINE_DATE="2026-10-30"
BASELINE_XCODE_LINES="27.1 27.2"          # major.minor lines treated as current
BASELINE_FLUTTER_LINES="3.47 3.50"        # Flutter minor lines treated as current
BASELINE_KNOWN_PKGS="foldable unfold duo_display duo_kit fold_kit foldable_device duo_layout responsive_framework responsive_builder flutter_screenutil custom_adaptive_scaffold dual_screen flutter_adaptive_scaffold adaptive_breakpoints"
STALE_REASONS=""

# age (GNU date on Linux, BSD date on macOS)
BASE_EPOCH="$(date -d "$BASELINE_DATE" +%s 2>/dev/null || date -j -f %Y-%m-%d "$BASELINE_DATE" +%s 2>/dev/null || echo 0)"
if [ "$BASE_EPOCH" -gt 0 ]; then
  AGE_DAYS=$(( ( $(date +%s) - BASE_EPOCH ) / 86400 ))
  echo "survey_baseline_age_days=${AGE_DAYS}"
  [ "$AGE_DAYS" -gt 100 ] && STALE_REASONS="${STALE_REASONS}baseline older than ~3 months; "
fi

# Xcode line (only known on macOS)
XC="$(xcodebuild -version 2>/dev/null | awk '/^Xcode/ {print $2}')"
if [ -n "$XC" ]; then
  XC_LINE="$(echo "$XC" | cut -d. -f1,2)"
  case " $BASELINE_XCODE_LINES " in *" $XC_LINE "*) ;; *) STALE_REASONS="${STALE_REASONS}Xcode ${XC} not in baseline lines (${BASELINE_XCODE_LINES}); ";; esac
  echo "survey_xcode_line=${XC_LINE}"
else
  echo "survey_xcode_line=unknown_not_macos"
fi

# Flutter line + packages
if [ "$STACK" = "flutter" ]; then
  # Installed or fvm-pinned Flutter is authoritative. A pubspec constraint is only a
  # lower bound: it can prove the project is NEWER than the baseline, never older.
  FL="${FV:-}"
  [ -z "$FL" ] && FL="$(sed -nE 's/.*"flutter"\s*:\s*"([^"]+)".*/\1/p' .fvmrc 2>/dev/null | head -n1)"
  if [ -n "$FL" ]; then
    FL_LINE="$(echo "$FL" | cut -d. -f1,2)"
    echo "survey_flutter_line=${FL_LINE}"
    case " $BASELINE_FLUTTER_LINES " in *" $FL_LINE "*) ;; *) STALE_REASONS="${STALE_REASONS}Flutter ${FL} not in baseline lines (${BASELINE_FLUTTER_LINES}); ";; esac
  else
    LB="$(awk '/^sdks:/{f=1;next} f&&/flutter:/{sub(/^[^:]*:[ ]*/,"");gsub(/[">=<^ ]/,"");print;exit}' pubspec.lock 2>/dev/null | cut -d' ' -f1)"
    echo "survey_flutter_line=unknown_installed (constraint lower bound ${LB:-?}; run on the Mac or with flutter on PATH)"
    if [ -n "$LB" ]; then
      LB_MINOR="$(echo "$LB" | cut -d. -f2)"; NEWEST_MINOR="$(echo "$BASELINE_FLUTTER_LINES" | tr ' ' '\n' | cut -d. -f2 | sort -n | tail -n1)"
      if [ "$(echo "$LB" | cut -d. -f1)" -gt 3 ] 2>/dev/null || [ "${LB_MINOR:-0}" -gt "${NEWEST_MINOR:-0}" ] 2>/dev/null; then
        STALE_REASONS="${STALE_REASONS}pubspec requires Flutter >= ${LB}, newer than the baseline lines (${BASELINE_FLUTTER_LINES}); "
      fi
    fi
  fi
  # any foldable/adaptive-looking package the baseline has never heard of?
  UNKNOWN=""
  for p in $(grep -oE '^\s{2}[a-z0-9_]*(fold|duo|hinge|adaptive|responsive|screenutil)[a-z0-9_]*\s*:' pubspec.yaml 2>/dev/null | tr -d ' :'); do
    case " $BASELINE_KNOWN_PKGS " in *" $p "*) ;; *) UNKNOWN="${UNKNOWN}${p} ";; esac
  done
  [ -n "$UNKNOWN" ] && STALE_REASONS="${STALE_REASONS}packages not in baseline: ${UNKNOWN}; "
  echo "survey_unknown_packages=${UNKNOWN:-none}"
fi

if [ -z "$STALE_REASONS" ]; then
  echo "survey=current"
else
  echo "survey=stale"
  echo "survey_stale_reasons=${STALE_REASONS}"
fi

# ---------- git context (reported for the hand-back summary; never changed) --
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git=yes"
  echo "git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "git_dirty=$([ -n "$(git status --porcelain 2>/dev/null)" ] && echo yes || echo no)"
else
  echo "git=no"
fi

echo "status=ok"
