#!/bin/bash
# Copy the diagnostics log off a connected iPhone and show the end of it.
# usage: tools/logs.sh [device-id]      default: the first iPhone that is plugged in or on the network
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE=${1:-$(xcrun devicectl list devices 2>/dev/null | awk '$4 ~ /^(connected|available)/ && /iPhone/ {print $3; exit}')}
if [ -z "$DEVICE" ]; then
  echo "No iPhone is connected. Plug one in and unlock it, or use Settings, Diagnostics, Share on the phone."
  exit 1
fi
mkdir -p build/device-logs
OUT="build/device-logs/${DEVICE:0:8}-$(date +%H%M%S).log"
xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer \
  --domain-identifier com.passbyplaza.app \
  --source "Library/Application Support/Passby/diagnostics.log" --destination "$OUT" > /dev/null
echo "$OUT"
tail -n 60 "$OUT"
