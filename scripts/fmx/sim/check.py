#!/usr/bin/env python3
# focusmaxxing hub simulator harness: did at least one driver take every screenshot the plan names?
# prints a table, writes it to $OUT/summary.txt, exits 1 when neither driver finished.
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
out = os.environ.get("OUT", "sim-out")
plan_path = os.environ.get("FMX_PLAN") or os.path.join(here, "plan.json")
with open(plan_path, encoding="utf-8") as handle:
    plan = json.load(handle)
wanted = [step["name"] for step in plan["steps"] if step.get("do") == "shot"]

lines = []
complete = []
for driver in ("idb", "xcui"):
    folder = os.path.join(out, driver)
    have = [name for name in wanted if os.path.isfile(os.path.join(folder, name + ".png"))]
    missing = [name for name in wanted if name not in have]
    lines.append("%-5s %d of %d screenshots%s" % (driver, len(have), len(wanted),
                                                  ("; missing " + ", ".join(missing)) if missing else ""))
    if not missing:
        complete.append(driver)

lines.append("complete: " + (", ".join(complete) if complete else "none"))
text = "\n".join(lines)
print(text)
os.makedirs(out, exist_ok=True)
with open(os.path.join(out, "summary.txt"), "w", encoding="utf-8") as handle:
    handle.write(text + "\n")
sys.exit(0 if complete else 1)
