#!/bin/bash
# Build for a real iPhone and install it.
# usage: tools/install.sh [device-id]      default: the first iPhone that is plugged in or on the network
# The first run registers the app with your Apple developer team and needs Xcode signed in to it.
set -euo pipefail
cd "$(dirname "$0")/.."
DD="$HOME/Library/Developer/Xcode/DerivedData/Passby-cli"
mkdir -p build
xcodegen -q
if ! xcodebuild -project Passby.xcodeproj -scheme Passby -configuration Release \
    -destination "generic/platform=iOS" -derivedDataPath "$DD" -allowProvisioningUpdates build > build/xcodebuild-device.log 2>&1; then
  grep -E "error:|error :" build/xcodebuild-device.log | sort -u | head -30
  exit 1
fi
DEVICE=${1:-$(xcrun devicectl list devices 2>/dev/null | awk '$4 ~ /^(connected|available)/ && /iPhone/ {print $3; exit}')}
if [ -z "$DEVICE" ]; then
  echo "Built, but no iPhone is connected. Plug one in, unlock it, and run this again."
  exit 1
fi
xcrun devicectl device install app --device "$DEVICE" "$DD/Build/Products/Release-iphoneos/Passby.app"
xcrun devicectl device process launch --device "$DEVICE" com.passbyplaza.app
