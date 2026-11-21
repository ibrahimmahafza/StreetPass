#!/bin/bash
# Build a release and upload it to TestFlight.
# usage: tools/testflight.sh
# Needs Xcode signed in to the developer team, and the app to exist in App Store Connect
# with the bundle ID com.passbyplaza.app. If the build number is already taken, Xcode raises it.
set -euo pipefail
cd "$(dirname "$0")/.."
# Homebrew's rsync makes Xcode's export step fail with "Copy failed"; find the system one first.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
DD="$HOME/Library/Developer/Xcode/DerivedData/Passby-cli"
ARCHIVE="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/Passby $(date +%H.%M.%S).xcarchive"
mkdir -p build "$(dirname "$ARCHIVE")"
xcodegen -q
if ! xcodebuild -project Passby.xcodeproj -scheme Passby -configuration Release \
    -destination "generic/platform=iOS" -derivedDataPath "$DD" -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates archive > build/xcodebuild-archive.log 2>&1; then
  grep -E "error:|error :" build/xcodebuild-archive.log | sort -u | head -30
  exit 1
fi
rm -rf "$DD/export"
if ! xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist tools/ExportOptions.plist \
    -exportPath "$DD/export" -allowProvisioningUpdates > build/xcodebuild-upload.log 2>&1; then
  grep -E "error:|error :" build/xcodebuild-upload.log | sort -u | head -30
  echo "Full log: build/xcodebuild-upload.log"
  exit 1
fi
echo "Uploaded. It appears in TestFlight once Apple has processed it, usually within 15 minutes."
