#!/usr/bin/env python3
# focusmaxxing hub simulator harness: walk plan.json with facebook's idb.
#
# taps and drags go through idb (idb_companion talks to the simulator); screenshots come from
# `xcrun simctl io <udid> screenshot`; every screenshot has an accessibility dump beside it from
# `idb ui describe-all` (<name>.tree.json). output: $OUT/idb/, a step log in $OUT/idb/steps.txt,
# the app's own log in $OUT/logs/app-idb.log.
#
# needs: UDID and OUT in the environment, idb_companion (brew tap facebook/fb; brew install
# idb-companion) and the idb client (pip install fb-idb) on PATH.
import json
import os
import re
import subprocess
import sys
import time

UDID = os.environ["UDID"]
OUT = os.environ["OUT"]
HERE = os.path.dirname(os.path.abspath(__file__))
PLAN = os.environ.get("FMX_PLAN") or os.path.join(HERE, "plan.json")
DEST = os.path.join(OUT, "idb")
LOGS = os.path.join(OUT, "logs")
os.makedirs(DEST, exist_ok=True)
os.makedirs(LOGS, exist_ok=True)

notes = []


def note(text):
    print(text, flush=True)
    notes.append(text)


def save_notes():
    with open(os.path.join(DEST, "steps.txt"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(notes) + "\n")


class StepError(Exception):
    pass


def sh(cmd, timeout=120, check=True):
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if check and result.returncode != 0:
        raise StepError("%s -> exit %d: %s" % (" ".join(cmd), result.returncode,
                                                (result.stderr or result.stdout).strip()[:800]))
    return result.stdout


def idb(*args, timeout=120):
    return sh(["idb", *args, "--udid", UDID], timeout=timeout)


# ---- companion -------------------------------------------------------------------------------

def start_companion():
    log_path = os.path.join(LOGS, "idb_companion.log")
    log = open(log_path, "w")
    companion = subprocess.Popen(["idb_companion", "--udid", UDID], stdout=log, stderr=subprocess.STDOUT)
    port = None
    started = time.time()
    while time.time() - started < 90:
        time.sleep(1)
        if companion.poll() is not None:
            raise StepError("idb_companion exited with %s; see logs/idb_companion.log" % companion.returncode)
        with open(log_path, encoding="utf-8", errors="replace") as handle:
            match = re.search(r'"grpc_port"\s*:\s*(\d+)', handle.read())
        if match:
            port = match.group(1)
            break
    if not port:
        raise StepError("idb_companion never printed its port; see logs/idb_companion.log")
    note("idb_companion is on port %s" % port)
    sh(["idb", "connect", "localhost", port])
    return companion


# ---- reading the screen ----------------------------------------------------------------------

def describe():
    raw = idb("ui", "describe-all")
    try:
        return json.loads(raw), raw
    except ValueError:
        raw = idb("ui", "describe-all", "--json")
        return json.loads(raw), raw


def frame_of(element):
    f = element.get("frame") or {}
    return float(f.get("x", 0)), float(f.get("y", 0)), float(f.get("width", 0)), float(f.get("height", 0))


def screen_size(elements):
    for element in elements:
        if element.get("type") == "Application":
            _x, _y, w, h = frame_of(element)
            if w and h:
                return w, h
    return 402.0, 874.0


def label_matches(element, label, match):
    text = element.get("AXLabel") or ""
    if match == "prefix":
        return text.startswith(label)
    if match == "contains":
        return label in text
    return text == label


def find(elements, label, match="exact", kind=None):
    width, height = screen_size(elements)
    found = []
    for element in elements:
        if element.get("type") == "Application" or not label_matches(element, label, match):
            continue
        x, y, w, h = frame_of(element)
        if kind == "tab" and y < height - 150:
            continue
        if kind in ("button", "tab") and element.get("type") != "Button":
            continue
        found.append(element)
    # a button before a text with the same words
    found.sort(key=lambda e: 0 if e.get("type") == "Button" else 1)
    return found[0] if found else None


def centre(element):
    x, y, w, h = frame_of(element)
    return int(round(x + w / 2)), int(round(y + h / 2))


# ---- acting --------------------------------------------------------------------------------

def tap_xy(x, y):
    idb("ui", "tap", str(int(x)), str(int(y)))


def drag(dy, x=8.0, hold=0.8):
    elements, _raw = describe()
    _w, height = screen_size(elements)
    remaining = float(dy)
    while abs(remaining) > 0.5:
        chunk = max(min(remaining, 400.0), -400.0)
        start_y = height * 0.75 if chunk > 0 else height * 0.25
        end_y = start_y - chunk
        idb("ui", "swipe", "--duration", "1.2", "--delta", "6",
            str(int(x)), str(int(start_y)), str(int(x)), str(int(end_y)))
        remaining -= chunk
        time.sleep(hold + 0.6)


def launch(step):
    bundle = PLAN_DATA.get("bundleId", "com.SideStore.SideStore")
    sh(["xcrun", "simctl", "terminate", UDID, bundle], check=False)
    time.sleep(1)
    sh(["xcrun", "simctl", "launch", UDID, bundle, *step.get("args", [])])
    if step.get("waitFor"):
        wait_for(step["waitFor"], step.get("waitType"), float(step.get("timeout", 120)))


def wait_for(label, kind, timeout):
    started = time.time()
    while time.time() - started < timeout:
        try:
            elements, _raw = describe()
            if find(elements, label, "exact", kind):
                note("  '%s' is on screen after %.0fs" % (label, time.time() - started))
                return
        except StepError as error:
            note("  describe failed while waiting: %s" % error)
        time.sleep(2)
    raise StepError("'%s' never appeared in %.0fs" % (label, timeout))


def shot(name):
    png = os.path.join(DEST, name + ".png")
    sh(["xcrun", "simctl", "io", UDID, "screenshot", png])
    try:
        elements, raw = describe()
        with open(os.path.join(DEST, name + ".tree.json"), "w", encoding="utf-8") as handle:
            json.dump(elements, handle, indent=1)
    except (StepError, ValueError) as error:
        with open(os.path.join(DEST, name + ".tree.json"), "w", encoding="utf-8") as handle:
            handle.write(json.dumps({"error": str(error)}))
    note("  saved %s.png" % name)


def dismiss_alerts(step):
    labels = step.get("tap", ["Allow", "OK"])
    deadline = time.time() + float(step.get("seconds", 4))
    while time.time() < deadline:
        elements, _raw = describe()
        target = None
        for label in labels:
            target = find(elements, label, "exact", "button")
            if target:
                break
        if target:
            note("  tapping alert button '%s'" % target.get("AXLabel"))
            tap_xy(*centre(target))
            time.sleep(1.5)
            continue
        time.sleep(1)


def expect_absent(step):
    label = step["label"]
    deadline = time.time() + float(step.get("seconds", 3))
    seen = False
    while time.time() < deadline and not seen:
        elements, _raw = describe()
        seen = find(elements, label, "exact") is not None
        time.sleep(1)
    if not seen:
        note("  '%s' is not on screen, as expected" % label)
        return
    note("  WARNING '%s' IS on screen" % label)
    if step.get("orRelaunchWith"):
        note("  relaunching with %s" % step["orRelaunchWith"])
        launch({"args": step["orRelaunchWith"], "waitFor": step.get("waitFor"), "waitType": step.get("waitType"),
                "timeout": step.get("timeout", 120)})


def tap(step):
    label = step["label"]
    match = step.get("match", "exact")
    kind = step.get("type")
    scroll_dy = float(step.get("scrollDy", 300))
    for attempt in range(int(step.get("maxScrolls", 0)) + 1):
        elements, _raw = describe()
        _w, height = screen_size(elements)
        element = find(elements, label, match, kind)
        if element:
            x, y, w, h = frame_of(element)
            inside = kind == "tab" or (y >= 110 and y + h <= height - 95)
            if inside:
                note("  tapping '%s' at %s" % (element.get("AXLabel"), centre(element)))
                tap_xy(*centre(element))
                return
        if attempt < int(step.get("maxScrolls", 0)):
            drag(scroll_dy)
    raise StepError("could not find '%s' (%s) on screen" % (label, match))


def back(_step):
    elements, _raw = describe()
    for element in elements:
        if element.get("type") == "Button" and (element.get("AXLabel") or "") in ("Back", "Focusmaxxing mobile"):
            tap_xy(*centre(element))
            return
    for element in elements:
        x, y, w, h = frame_of(element)
        if element.get("type") == "Button" and y < 140 and x < 160:
            note("  tapping top-left button '%s'" % element.get("AXLabel"))
            tap_xy(*centre(element))
            return
    raise StepError("no back button")


ACTIONS = {
    "launch": launch,
    "dismissAlerts": dismiss_alerts,
    "expectAbsent": expect_absent,
    "shot": lambda step: shot(step["name"]),
    "drag": lambda step: drag(float(step["dy"]), float(step.get("x", 8)), float(step.get("hold", 0.8))),
    "scrollToTop": lambda step: [drag(-800) for _ in range(3)],
    "tap": tap,
    "tapPoint": lambda step: tap_xy(step["x"], step["y"]),
    "back": back,
    "sleep": lambda step: time.sleep(float(step.get("seconds", 1))),
}

with open(PLAN, encoding="utf-8") as plan_handle:
    PLAN_DATA = json.load(plan_handle)


def main():
    app_log = open(os.path.join(LOGS, "app-idb.log"), "w")
    stream = subprocess.Popen(["xcrun", "simctl", "spawn", UDID, "log", "stream", "--style", "compact",
                               "--level", "debug", "--predicate", 'process == "SideStore"'],
                              stdout=app_log, stderr=subprocess.STDOUT)
    companion = None
    failures = 0
    try:
        companion = start_companion()
        for index, step in enumerate(PLAN_DATA["steps"], 1):
            action = step.get("do")
            note("step %d: %s %s" % (index, action, json.dumps({k: v for k, v in step.items() if k != "do"})))
            try:
                ACTIONS[action](step)
            except Exception as error:  # keep going: the later screenshots are still worth having
                failures += 1
                note("  FAILED: %s" % error)
                try:
                    shot("failed-step-%02d" % index)
                except Exception:
                    pass
    except Exception as error:
        failures += 1
        note("FAILED before the plan could run: %s" % error)
    finally:
        save_notes()
        stream.terminate()
        if companion:
            companion.terminate()
    note("done, %d failed step(s)" % failures)
    save_notes()
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
