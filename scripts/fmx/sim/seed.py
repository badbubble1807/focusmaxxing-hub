#!/usr/bin/env python3
# focusmaxxing hub simulator harness: write the seed into the app before its first launch.
#
# 1. every scripts/fmx/sim/seeds/*.json is merged in name order (keys starting with _ are notes,
#    a null value removes the key) and written into the app's own UserDefaults file,
#    <data container>/Library/Preferences/<bundle id>.plist. that is UserDefaults.standard inside
#    the app. json true/false become booleans, whole numbers integers, 1.5 a real, lists arrays,
#    objects dictionaries - so "fmx.fullblock.custom": [{"id": "custom.a", "name": "Snapchat"}]
#    arrives as the [[String: String]] FMXFullBlock.customApps() reads.
# 2. FMX_SEED_JSON, if set in the workflow's environment, is one more json object merged last.
# 3. files under seeds/files/data/ are copied into the data container (Documents/..., Library/...)
#    and files under seeds/files/group/ into the shared app-group folder, which is where
#    focusmaxxing-switches.plist and the focusmaxxing-media folder live.
#
# it must run before the app has ever been launched on this simulator: once the app has read its
# settings the system caches them and a file written underneath is not seen.
import argparse
import glob
import json
import os
import plistlib
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("--data", required=True)
parser.add_argument("--group", default="")
parser.add_argument("--bundle-id", required=True)
parser.add_argument("--out", required=True)
args = parser.parse_args()

here = os.path.dirname(os.path.abspath(__file__))
report = []

merged = {}
for path in sorted(glob.glob(os.path.join(here, "seeds", "*.json"))):
    with open(path, encoding="utf-8") as handle:
        merged.update(json.load(handle))
    report.append("seed file: " + os.path.basename(path))
extra = os.environ.get("FMX_SEED_JSON", "").strip()
if extra:
    merged.update(json.loads(extra))
    report.append("seed from FMX_SEED_JSON")

prefs_dir = os.path.join(args.data, "Library", "Preferences")
os.makedirs(prefs_dir, exist_ok=True)
plist_path = os.path.join(prefs_dir, args.bundle_id + ".plist")
current = {}
if os.path.exists(plist_path):
    with open(plist_path, "rb") as handle:
        current = plistlib.load(handle)

for key, value in merged.items():
    if key.startswith("_"):
        continue
    if value is None:
        current.pop(key, None)
        report.append("removed " + key)
    else:
        current[key] = value
        report.append("set %s = %s" % (key, json.dumps(value)))

with open(plist_path, "wb") as handle:
    plistlib.dump(current, handle, fmt=plistlib.FMT_BINARY)
report.append("wrote " + plist_path)


def copy_tree(source, destination, label):
    if not os.path.isdir(source):
        return
    if not destination:
        report.append("SKIPPED %s files: no %s container (is the app signed with the app group?)" % (label, label))
        return
    shutil.copytree(source, destination, dirs_exist_ok=True)
    for root, _dirs, files in os.walk(source):
        for name in files:
            relative = os.path.relpath(os.path.join(root, name), source)
            report.append("copied %s file %s" % (label, relative))


copy_tree(os.path.join(here, "seeds", "files", "data"), args.data, "data")
copy_tree(os.path.join(here, "seeds", "files", "group"), args.group, "group")
report.append("data container: " + args.data)
report.append("group container: " + (args.group or "(none)"))

with open(args.out, "w", encoding="utf-8") as handle:
    handle.write("\n".join(report) + "\n")
