#!/usr/bin/env python3
# focusmaxxing hub simulator harness: did at least one driver take every screenshot the plan names?
# prints a table, writes it to $OUT/summary.txt, exits 1 when neither driver finished.
#
# FMX_EXTRA_CHECKS (optional) lists more passes as "plan-file=folder;plan-file=folder", plan files
# relative to this folder (item 2 before-state: plan-signed-in.json=xcui-signed-in, and so on).
# the run is green only when the main plan AND every extra pass took all their screenshots.
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
out = os.environ.get("OUT", "sim-out")


def wanted_shots(plan_path):
    with open(plan_path, encoding="utf-8") as handle:
        plan = json.load(handle)
    return [step["name"] for step in plan["steps"] if step.get("do") == "shot"]


def count(folder, wanted):
    have = [name for name in wanted if os.path.isfile(os.path.join(out, folder, name + ".png"))]
    missing = [name for name in wanted if name not in have]
    return have, missing


lines = []
ok = True

plan_path = os.environ.get("FMX_PLAN") or os.path.join(here, "plan.json")
wanted = wanted_shots(plan_path)
complete = []
for driver in ("idb", "xcui"):
    have, missing = count(driver, wanted)
    lines.append("%-15s %d of %d screenshots%s" % (driver, len(have), len(wanted),
                                                   ("; missing " + ", ".join(missing)) if missing else ""))
    if not missing:
        complete.append(driver)
lines.append("complete (plan.json): " + (", ".join(complete) if complete else "none"))
ok = ok and bool(complete)

for pair in filter(None, os.environ.get("FMX_EXTRA_CHECKS", "").split(";")):
    plan_file, folder = pair.split("=", 1)
    wanted = wanted_shots(os.path.join(here, plan_file.strip()))
    have, missing = count(folder.strip(), wanted)
    lines.append("%-15s %d of %d screenshots (%s)%s" % (folder.strip(), len(have), len(wanted), plan_file.strip(),
                                                        ("; missing " + ", ".join(missing)) if missing else ""))
    ok = ok and not missing

lines.append("green: " + ("yes" if ok else "no"))
text = "\n".join(lines)
print(text)
os.makedirs(out, exist_ok=True)
with open(os.path.join(out, "summary.txt"), "w", encoding="utf-8") as handle:
    handle.write(text + "\n")
sys.exit(0 if ok else 1)
