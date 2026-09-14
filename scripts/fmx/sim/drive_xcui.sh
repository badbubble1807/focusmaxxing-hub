#!/bin/bash
# focusmaxxing hub simulator harness: walk plan.json with a throwaway XCUITest bundle.
#
# xcodegen makes a tiny project from xcui/project.yml (a do-nothing host app and a ui-test bundle).
# the test, xcui/UITests/PlanRunner.swift, drives the already-installed Hub by its bundle id, so the
# Hub's own project is never touched. screenshots are XCUIScreen's (the whole screen, status bar
# included), dumps are XCUIApplication.debugDescription. output: $OUT/xcui/.
set -uo pipefail
: "${UDID:?UDID must be set}" "${OUT:?OUT must be set}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# FMX_XCUI_NAME names this pass's output folder and logs (default xcui), so one run can walk several plans
NAME="${FMX_XCUI_NAME:-xcui}"
DEST="$OUT/$NAME"
mkdir -p "$DEST" "$OUT/logs"

xcrun simctl spawn "$UDID" log stream --style compact --level debug --predicate 'process == "SideStore"' \
  > "$OUT/logs/app-$NAME.log" 2>&1 &
LOG_PID=$!

cd "$HERE/xcui" || exit 1
xcodegen generate || exit 1

# xcodebuild hands every TEST_RUNNER_ variable to the test process with the prefix taken off
export TEST_RUNNER_FMX_PLAN="${FMX_PLAN:-$HERE/plan.json}"
export TEST_RUNNER_FMX_OUT="$DEST"
export TEST_RUNNER_FMX_BUNDLE_ID="${BUNDLE_ID:-com.SideStore.SideStore}"

rm -rf "${RUNNER_TEMP:-/tmp}/$NAME.xcresult"
xcodebuild test -project FMXSimDriver.xcodeproj -scheme FMXSimDriver -destination "id=$UDID" \
  -resultBundlePath "${RUNNER_TEMP:-/tmp}/$NAME.xcresult" \
  2>&1 | tee "$OUT/logs/$NAME-test.log" | xcbeautify --renderer github-actions
STATUS=${PIPESTATUS[0]}

kill "$LOG_PID" 2>/dev/null || true
exit "$STATUS"
