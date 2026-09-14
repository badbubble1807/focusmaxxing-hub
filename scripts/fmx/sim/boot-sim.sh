#!/bin/bash
# focusmaxxing hub simulator harness: make a fresh iPhone on the newest iOS 26.x runtime, boot it,
# and pin the status bar (9:41, full battery) so screenshots from different runs compare cleanly.
# writes UDID into $GITHUB_ENV and what it chose into $OUT/meta.txt.
#
# FMX_SIM_DEVICE picks another model ("iPhone 16e", "iPhone 17 Pro Max"); default iPhone 17 Pro.
set -euo pipefail
: "${OUT:?OUT must be set}"
mkdir -p "$OUT"

xcrun simctl list runtimes > "$OUT/runtimes.txt"

RUNTIME=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"]
      if r.get("isAvailable") and r.get("name", "").startswith("iOS ") and r.get("version", "").startswith("26.")]
rs.sort(key=lambda r: [int(x) for x in r["version"].split(".")])
print(rs[-1]["identifier"] if rs else "")
')
if [ -z "$RUNTIME" ]; then
  echo "no iOS 26.x simulator runtime on this runner:"
  cat "$OUT/runtimes.txt"
  exit 1
fi

DEVICE_NAME="${FMX_SIM_DEVICE:-iPhone 17 Pro}"
DEVICE_TYPE=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
want = sys.argv[1]
for d in json.load(sys.stdin)["devicetypes"]:
    if d["name"] == want:
        print(d["identifier"])
        break
' "$DEVICE_NAME")
if [ -z "$DEVICE_TYPE" ]; then
  # that model is not on this Xcode; take the newest iPhone the runtime supports
  DEVICE_TYPE=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rid = sys.argv[1]
for r in json.load(sys.stdin)["runtimes"]:
    if r["identifier"] == rid:
        phones = [d for d in r.get("supportedDeviceTypes", []) if d.get("productFamily") == "iPhone"]
        print(phones[-1]["identifier"] if phones else "")
' "$RUNTIME")
  DEVICE_NAME="$DEVICE_TYPE"
fi

UDID=$(xcrun simctl create fmx-harness "$DEVICE_TYPE" "$RUNTIME")
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true

echo "UDID=$UDID" >> "$GITHUB_ENV"
{
  echo "runtime: $RUNTIME"
  echo "device: $DEVICE_NAME ($DEVICE_TYPE)"
  echo "udid: $UDID"
  echo "ref: ${GITHUB_REF_NAME:-}"
  echo "head: ${GITHUB_SHA:-}"
  xcodebuild -version
} > "$OUT/meta.txt"
cat "$OUT/meta.txt"
