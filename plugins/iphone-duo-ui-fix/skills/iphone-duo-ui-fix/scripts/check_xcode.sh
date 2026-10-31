#!/usr/bin/env bash
# check_xcode.sh — verify the active Xcode is new enough for iPhone Duo work.
#
# Usage:  scripts/check_xcode.sh [MIN_VERSION]      (default MIN_VERSION=27.1)
# Output: key=value lines on stdout (easy to grep), human summary on stderr.
# Exit:   0 = OK, 1 = Xcode too old, 2 = Xcode/xcodebuild not found, 3 = not macOS
#
# Written for the bash 3.2 that ships with macOS (no arrays-of-arrays, no mapfile).

set -u
MIN_VERSION="${1:-27.1}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "status=not_macos"
  echo "Xcode can only be checked on macOS. If this session runs in a cloud sandbox, run this script on the Mac that has the project checked out." >&2
  exit 3
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "status=xcode_not_found"
  echo "xcodebuild not found. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app" >&2
  exit 2
fi

DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
# xcodebuild -version prints e.g. "Xcode 27.1\nBuild version 27B123"
XCODE_VER="$(xcodebuild -version 2>/dev/null | awk '/^Xcode/ {print $2}')"
XCODE_BUILD="$(xcodebuild -version 2>/dev/null | awk '/^Build version/ {print $3}')"
SWIFT_VER="$(xcrun swift --version 2>/dev/null | head -n 1 | sed -E 's/.*Swift version ([0-9.]+).*/\1/')"
IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || true)"
IOS_SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"

echo "developer_dir=${DEV_DIR}"
echo "xcode_version=${XCODE_VER:-unknown}"
echo "xcode_build=${XCODE_BUILD:-unknown}"
echo "swift_version=${SWIFT_VER:-unknown}"
echo "ios_sdk=${IOS_SDK:-unknown}"
echo "ios_simulator_sdk=${IOS_SIM_SDK:-unknown}"
echo "min_required=${MIN_VERSION}"

if [ -z "${XCODE_VER}" ]; then
  echo "status=version_unreadable"
  echo "Could not parse 'xcodebuild -version'. Is the Xcode license accepted? Try: sudo xcodebuild -license accept" >&2
  exit 2
fi

# Compare dotted versions numerically: "27.1" >= "27.0.1" etc.
ver_ge() {
  # returns 0 if $1 >= $2
  local a="$1" b="$2" i ai bi
  i=1
  while :; do
    # trailing dot so that `cut` returns "" (not the whole string) past the last field
    ai="$(echo "$a." | cut -d. -f"$i")"
    bi="$(echo "$b." | cut -d. -f"$i")"
    [ -z "$ai" ] && [ -z "$bi" ] && return 0
    ai="${ai:-0}"; bi="${bi:-0}"
    if [ "$ai" -gt "$bi" ] 2>/dev/null; then return 0; fi
    if [ "$ai" -lt "$bi" ] 2>/dev/null; then return 1; fi
    i=$((i+1))
    [ "$i" -gt 6 ] && return 0
  done
}

if ver_ge "${XCODE_VER}" "${MIN_VERSION}"; then
  echo "status=ok"
  echo "OK: Xcode ${XCODE_VER} (${XCODE_BUILD}) at ${DEV_DIR}; Swift ${SWIFT_VER:-?}; iOS SDK ${IOS_SDK:-?}" >&2
  exit 0
else
  echo "status=too_old"
  echo "Xcode ${XCODE_VER} is older than ${MIN_VERSION}. iPhone Duo needs Xcode ${MIN_VERSION}+ (27A9275, Swift 6.4, iOS 27.1 SDK): earlier SDKs put the app in compatibility mode and Xcode 27.0 has no Duo simulator. Update via the App Store or https://developer.apple.com/download/ and re-run 'sudo xcode-select -s /Applications/Xcode.app'." >&2
  exit 1
fi
