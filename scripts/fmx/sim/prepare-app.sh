#!/bin/bash
# focusmaxxing hub simulator harness: put a fresh copy of the app on the simulator and write the
# seed into it before its first launch. every driver starts from here, so each one sees a first
# launch of its own. usage: prepare-app.sh <driver name>
set -euo pipefail
: "${UDID:?UDID must be set}" "${APP:?APP must be set}" "${OUT:?OUT must be set}"
DRIVER="${1:-run}"
BUNDLE_ID="${BUNDLE_ID:-com.SideStore.SideStore}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT/logs"

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
# the app group only resolves when sign-for-sim.sh gave the app the entitlement
GROUP=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" "group.$BUNDLE_ID" 2>/dev/null || true)

python3 "$HERE/seed.py" --data "$DATA" --group "$GROUP" --bundle-id "$BUNDLE_ID" \
  --out "$OUT/logs/seed-$DRIVER.txt"
cat "$OUT/logs/seed-$DRIVER.txt"
