#!/usr/bin/env bash
# capture_duo_screens.sh — screenshot the iPhone Duo simulator into the same
# outer/ inner/ inner_portrait/ layout the skill uses for input screenshots,
# so before/after pairs line up.
#
# Usage:
#   scripts/capture_duo_screens.sh <out_root> <folder> <name> [--udid UDID] [--display primary|primary-1]
#     <folder>   outer | inner | inner_portrait       (where to save; inner = Apple's inner landscape)
#     <name>     screen name, e.g. home               (saved as <out_root>/<folder>/<name>.png)
#     --display  which simulator display to capture; default: primary-1 (inner) for
#                inner/inner_portrait, primary (outer) for outer. On builds whose
#                `simctl io enumerate` shows numeric ids, pass that id instead.
#   scripts/capture_duo_screens.sh --list              booted simulators, Duo UDIDs, display ids
#
# The script does NOT change pose or rotation (there is no simctl command for the
# fold). Set the pose first — Device Hub buttons, or `hinge`/`duoctl` if installed —
# then capture. Wait 1–3 s after a pose change; an inactive display captures black.
#
# macOS only (xcrun simctl, sips).

set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script needs macOS with Xcode 27.1. Run it on the Mac that has the simulator." >&2
  exit 3
fi

if [ "${1:-}" = "--list" ]; then
  echo "--- booted simulators ---"
  xcrun simctl list devices booted
  echo "--- iPhone Duo simulators (any state) ---"
  xcrun simctl list devices | grep -i duo || echo "(none — see references/validation-on-device.md to create one)"
  BOOTED="$(xcrun simctl list devices booted | sed -nE 's/.*\(([0-9A-F-]{36})\).*/\1/p' | head -n1)"
  if [ -n "$BOOTED" ]; then
    echo "--- displays of $BOOTED ---"
    xcrun simctl io "$BOOTED" enumerate 2>/dev/null | grep -iE 'display|primary|class' || true
  fi
  echo "--- pose tools on PATH ---"
  for t in hinge duoctl devicehubctl; do command -v "$t" >/dev/null 2>&1 && echo "$t: $(command -v "$t")" || echo "$t: not installed"; done
  exit 0
fi

OUT_ROOT="${1:?out_root}"; FOLDER="${2:?outer|inner|inner_portrait}"; NAME="${3:?name}"
shift 3
UDID="booted"; DISPLAY_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --udid) UDID="$2"; shift 2 ;;
    --display) DISPLAY_ID="$2"; shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac
done

case "$FOLDER" in
  outer) [ -n "$DISPLAY_ID" ] || DISPLAY_ID="primary" ;;
  inner_landscape) FOLDER="inner"; [ -n "$DISPLAY_ID" ] || DISPLAY_ID="primary-1" ;;  # alias
  inner|inner_portrait) [ -n "$DISPLAY_ID" ] || DISPLAY_ID="primary-1" ;;
  *) echo "folder must be outer, inner or inner_portrait" >&2; exit 2 ;;
esac

mkdir -p "$OUT_ROOT/$FOLDER"
DEST="$OUT_ROOT/$FOLDER/$NAME.png"
xcrun simctl io "$UDID" screenshot --type=png --display="$DISPLAY_ID" "$DEST"

W="$(sips -g pixelWidth "$DEST" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
H="$(sips -g pixelHeight "$DEST" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
LABEL="unknown size"
case "${W}x${H}" in
  1398x2034) LABEL="outer portrait" ;;
  2034x1398) LABEL="outer landscape" ;;
  2853x2007) LABEL="inner landscape (951x669 pt)" ;;
  2007x2853) LABEL="inner portrait (669x951 pt)" ;;
esac
echo "saved $DEST (${W:-?}x${H:-?} px, $LABEL)"
case "$FOLDER:$LABEL" in
  outer:outer*|inner:"inner landscape"*|inner_portrait:"inner portrait"*|*:"unknown size") ;;
  *) echo "WARNING: capture is '$LABEL' but was saved to '$FOLDER/' — wrong --display, or the pose/rotation is not what you think" >&2 ;;
esac
