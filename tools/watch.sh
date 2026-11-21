#!/bin/bash
# Launch the app on a connected iPhone and print its diagnostics as they happen. Ctrl-C to stop watching.
# usage: tools/watch.sh [device-id]     default: the first iPhone that is plugged in or on the network
set -euo pipefail
DEVICE=${1:-$(xcrun devicectl list devices 2>/dev/null | awk '$4 ~ /^(connected|available)/ && /iPhone/ {print $3; exit}')}
if [ -z "$DEVICE" ]; then
  echo "No iPhone is connected. Plug one in and unlock it."
  exit 1
fi
xcrun devicectl device process launch --console --terminate-existing --device "$DEVICE" com.passbyplaza.app 2>&1 | grep --line-buffered "PASSBY" | sed -l 's/^.*PASSBY //'
