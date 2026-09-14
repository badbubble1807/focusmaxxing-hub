#!/bin/bash
# focusmaxxing hub simulator harness: sign the simulator build ad hoc, with the app group.
#
# the build runs with CODE_SIGNING_ALLOWED=NO, exactly like build hub. a phone build is then
# signed by the phone; a simulator build has nobody to do that, and the simulator only hands an
# app its shared app-group folder (FileManager.containerURL(forSecurityApplicationGroupIdentifier:),
# where the switches file and the block media live) and its keychain when the signature names
# them. so sign every framework inside first, then the app with the three entitlements Xcode
# itself gives a simulator build. usage: sign-for-sim.sh <path to SideStore.app> [app group]
set -euo pipefail
APP="${1:?path to the .app}"
GROUP="${2:-group.com.SideStore.SideStore}"
PREFIX="XYZ0123456"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")

ENT="$(mktemp -d)/sim.entitlements"
cat > "$ENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>application-identifier</key>
  <string>$PREFIX.$BUNDLE_ID</string>
  <key>keychain-access-groups</key>
  <array>
    <string>$PREFIX.$BUNDLE_ID</string>
  </array>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>$GROUP</string>
  </array>
</dict>
</plist>
EOF

# inside out: -depth lists what is inside a bundle before the bundle
find "$APP" -depth \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' \) -print0 |
  while IFS= read -r -d '' item; do
    echo "signing $(basename "$item")"
    codesign --force --sign - --timestamp=none "$item"
  done

codesign --force --sign - --timestamp=none --generate-entitlement-der --entitlements "$ENT" "$APP"
echo "signed $APP ($BUNDLE_ID)"
codesign -d --entitlements - "$APP" 2>&1 || true
