#!/usr/bin/env bash
# check_app_sdk.sh — which iOS SDK a built .app was linked against. The SDK stamp
# (LC_BUILD_VERSION) is what decides whether iPhone Duo shows the app edge to edge
# (27.1), with a black rail (27.0), or centered in a black frame (<= 26).
#
# Usage:  scripts/check_app_sdk.sh <path/to/App.app> [MIN_SDK]     (default MIN_SDK=27.1)
# Exit:   0 ok, 1 too old, 2 cannot read, 3 not macOS

set -u
APP="${1:?path to .app}"; MIN="${2:-27.1}"

if [ "$(uname -s)" != "Darwin" ]; then echo "status=not_macos"; exit 3; fi
[ -d "$APP" ] || { echo "status=not_found"; echo "no such .app: $APP" >&2; exit 2; }

EXE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist" 2>/dev/null || true)"
BIN="$APP/${EXE:-}"
[ -n "$EXE" ] && [ -f "$BIN" ] || { echo "status=no_binary"; exit 2; }

SDK="$(otool -l "$BIN" 2>/dev/null | awk '/LC_BUILD_VERSION/ {f=1} f && /sdk/ {print $2; exit}')"
MINOS="$(otool -l "$BIN" 2>/dev/null | awk '/LC_BUILD_VERSION/ {f=1} f && /minos/ {print $2; exit}')"
echo "binary=$BIN"
echo "linked_sdk=${SDK:-unknown}"
echo "min_os=${MINOS:-unknown}"
echo "min_required=$MIN"
[ -n "$SDK" ] || { echo "status=unreadable"; exit 2; }

# dotted compare (same approach as check_xcode.sh)
ver_ge() {
  local a="$1" b="$2" i=1 ai bi
  while :; do
    ai="$(echo "$a." | cut -d. -f"$i")"; bi="$(echo "$b." | cut -d. -f"$i")"
    [ -z "$ai" ] && [ -z "$bi" ] && return 0
    ai="${ai:-0}"; bi="${bi:-0}"
    [ "$ai" -gt "$bi" ] 2>/dev/null && return 0
    [ "$ai" -lt "$bi" ] 2>/dev/null && return 1
    i=$((i+1)); [ "$i" -gt 6 ] && return 0
  done
}

if ver_ge "$SDK" "$MIN"; then
  echo "status=ok"
else
  echo "status=too_old"
  echo "Linked against iOS SDK $SDK (< $MIN): iPhone Duo will letterbox this build regardless of code. Rebuild with Xcode 27.1 (check 'xcode-select -p' and the scheme's DEVELOPER_DIR)." >&2
  exit 1
fi
