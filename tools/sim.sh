#!/bin/bash
# Build, install and launch in the simulator in a demo state, then take a screenshot.
# usage: tools/sim.sh <demo> [out.png]      demo: plaza waiting card me people settings onboarding gallery
# env:   SIM=<simulator udid>  WAIT=<seconds before the screenshot>  NOBUILD=1 to skip the build
#        SHOT_MAX=<longest side of the screenshot in pixels>
set -euo pipefail
cd "$(dirname "$0")/.."
DEMO=${1:-plaza}
OUT=${2:-build/shots/$DEMO.png}
# The last iPhone 17 Pro listed is the one on the newest simulator runtime.
SIM=${SIM:-$(xcrun simctl list devices available | awk '/iPhone 17 Pro \(/{id=$0; sub(/.*Pro \(/,"",id); sub(/\).*/,"",id); best=id} END{print best}')}
# Build products live outside ~/Desktop: code signing fails on files the Desktop sync has touched.
DD="$HOME/Library/Developer/Xcode/DerivedData/Passby-cli"
mkdir -p build "$(dirname "$OUT")"
if [ -z "${NOBUILD:-}" ]; then
  xcodegen -q
  if ! xcodebuild -project Passby.xcodeproj -scheme Passby -configuration Debug \
      -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" build > build/xcodebuild.log 2>&1; then
    grep -E "error:|error :" build/xcodebuild.log | sort -u | head -40
    exit 1
  fi
fi
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b > /dev/null
xcrun simctl terminate "$SIM" com.passbyplaza.app 2>/dev/null || true
xcrun simctl install "$SIM" "$DD/Build/Products/Debug-iphonesimulator/Passby.app"
xcrun simctl launch "$SIM" com.passbyplaza.app -reset -demo "$DEMO" > /dev/null
sleep "${WAIT:-3}"
xcrun simctl io "$SIM" screenshot "$OUT" > /dev/null 2>&1
sips -Z "${SHOT_MAX:-1300}" "$OUT" > /dev/null 2>&1 || true
echo "$OUT"
