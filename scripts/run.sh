#!/usr/bin/env bash
# Build and launch MyExpense on the iOS Simulator or a connected iPhone.
#
#   scripts/run.sh simulator                       # first available iPhone simulator
#   TEAM_ID=ABCDE12345 BUNDLE_ID=com.yourname.myexpense scripts/run.sh device
#
# Optional: SIM_NAME="iPhone 17 Pro", DEVICE_ID=<UDID> (defaults to the first connected iPhone).
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED=build/DerivedData
BUNDLE_ID="${BUNDLE_ID:-com.example.myexpense.app}"

fail() { echo "error: $*" >&2; exit 1; }

usage() { sed -n '2,7p' "$0"; exit 1; }
[[ "${1:-}" == simulator || "${1:-}" == device ]] || usage

xcodebuild -version >/dev/null 2>&1 || fail "Full Xcode is required. Install Xcode from the App Store, then run:
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  xcodebuild -runFirstLaunch"
command -v xcodegen >/dev/null || fail "XcodeGen is required: brew install xcodegen"

xcodegen generate --quiet

case "$1" in
simulator)
    if [[ -z "${SIM_NAME:-}" ]]; then
        SIM_NAME=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
names = [d["name"] for runtime, items in devices.items() if "iOS" in runtime for d in items if d["name"].startswith("iPhone")]
print(names[-1] if names else "")')
    fi
    [[ -n "$SIM_NAME" ]] || fail "No iPhone simulator found. Install an iOS runtime in Xcode › Settings › Components."
    echo "▶ Building for simulator: $SIM_NAME"
    xcodebuild -project MyExpense.xcodeproj -scheme MyExpense -configuration Debug \
        -destination "platform=iOS Simulator,name=$SIM_NAME" -derivedDataPath "$DERIVED" build -quiet
    xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
    open -a Simulator
    xcrun simctl install "$SIM_NAME" "$DERIVED/Build/Products/Debug-iphonesimulator/MyExpense.app"
    xcrun simctl launch "$SIM_NAME" "$BUNDLE_ID"
    ;;
device)
    [[ -n "${TEAM_ID:-}" ]] || fail "Set TEAM_ID (Xcode › Settings › Accounts › your team)."
    [[ "$BUNDLE_ID" != com.example.* ]] || fail "Set BUNDLE_ID to something unique, e.g. BUNDLE_ID=com.yourname.myexpense"
    if [[ -z "${DEVICE_ID:-}" ]]; then
        tmp=$(mktemp)
        xcrun devicectl list devices --json-output "$tmp" >/dev/null
        DEVICE_ID=$(python3 -c '
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    hw = d.get("hardwareProperties", {})
    if hw.get("platform") == "iOS" and hw.get("deviceType") == "iPhone" and d.get("connectionProperties", {}).get("pairingState") == "paired":
        print(hw.get("udid", "")); break' "$tmp")
        rm -f "$tmp"
    fi
    [[ -n "$DEVICE_ID" ]] || fail "No paired iPhone found. Connect it with a cable, unlock it, tap Trust, and enable Developer Mode."
    echo "▶ Building for iPhone $DEVICE_ID (team $TEAM_ID, bundle $BUNDLE_ID)"
    xcodebuild -project MyExpense.xcodeproj -scheme MyExpense -configuration Debug \
        -destination "id=$DEVICE_ID" -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGN_STYLE=Automatic build -quiet
    xcrun devicectl device install app --device "$DEVICE_ID" "$DERIVED/Build/Products/Debug-iphoneos/MyExpense.app"
    xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
    ;;
esac
