#!/bin/bash
# focusmaxxing hub simulator harness: sign the simulator build the way xcode signs one.
#
# the workflow takes the widget extension out of the built app (the shipped hub has none), which
# changes the bundle, so it has to be signed again. a simulator app is signed ad hoc with NO
# entitlements in the signature - xcode itself runs `codesign --force --sign - --timestamp=none
# --generate-entitlement-der` - because the simulator reads an app's entitlements (the app group
# that holds the switches file and the block media) from a __TEXT,__entitlements section the
# linker wrote into the binary. putting entitlements into an ad-hoc signature instead gets the app
# killed at launch: "SIGKILL (Code Signature Invalid)", "Taskgated Invalid Signature" (run 2).
#
# usage: sign-for-sim.sh <path to SideStore.app>
set -euo pipefail
APP="${1:?path to the .app}"
BIN="$APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"

# inside out: -depth lists what is inside a bundle before the bundle
find "$APP" -depth \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' \) -print0 |
  while IFS= read -r -d '' item; do
    echo "signing $(basename "$item")"
    codesign --force --sign - --timestamp=none "$item"
  done

codesign --force --sign - --timestamp=none --generate-entitlement-der "$APP"
echo "signed $APP"
codesign --verify --deep --strict "$APP" && echo "the signature verifies"

# what the simulator will read as the app's entitlements
python3 - "$BIN" <<'PY'
import struct
import sys

data = open(sys.argv[1], "rb").read()


def section(offset):
    ncmds = struct.unpack_from("<I", data, offset + 16)[0]
    at = offset + 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, at)
        if cmd == 0x19:  # LC_SEGMENT_64
            nsects = struct.unpack_from("<I", data, at + 64)[0]
            s = at + 72
            for _ in range(nsects):
                name = data[s:s + 16].rstrip(b"\0").decode()
                if name == "__entitlements":
                    length = struct.unpack_from("<Q", data, s + 40)[0]
                    start = struct.unpack_from("<I", data, s + 48)[0]
                    return data[offset + start:offset + start + length]
                s += 80
        at += size
    return None


magic = struct.unpack_from(">I", data, 0)[0]
slices = []
if magic == 0xCAFEBABE:
    for i in range(struct.unpack_from(">I", data, 4)[0]):
        slices.append(struct.unpack_from(">I", data, 8 + i * 20 + 8)[0])
else:
    slices.append(0)
for offset in slices:
    found = section(offset)
    if found is None:
        print("the binary has NO __entitlements section: no app group, no keychain group in the simulator")
    else:
        print("entitlements linked into the binary:")
        print(found.decode("utf-8", "replace").strip("\0"))
PY

/usr/libexec/PlistBuddy -c 'Print :ALTAppGroups' "$APP/Info.plist" 2>&1 || true
