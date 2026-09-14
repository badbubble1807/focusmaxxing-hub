#!/usr/bin/env python3
# focusmaxxing hub simulator harness, item 2 before-state: TEST DATA ONLY, on a throwaway simulator.
#
# a CI simulator cannot sign in with a real Apple ID, and the first run's step 3 only offers Next
# once DatabaseManager.activeTeam() finds a Team with isActiveTeam == YES. this writes one Account
# and one Team row (a free developer account, type 1) straight into the Hub's Core Data store,
# AltStore.sqlite, after the app has created it and been stopped. nothing about the app is changed.
#
# needs UDID (and BUNDLE_ID) in the environment. prints the schema it found, so a failure explains
# itself. exit 1 when the store or a column it needs is missing.
import os
import sqlite3
import subprocess
import sys

udid = os.environ["UDID"]
bundle = os.environ.get("BUNDLE_ID", "com.SideStore.SideStore")


def container(kind):
    result = subprocess.run(["xcrun", "simctl", "get_app_container", udid, bundle, kind],
                            capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


roots = []
data = container("data")
if data:
    roots.append(data)
for line in container("groups").splitlines():
    parts = line.strip().split(None, 1)
    if len(parts) == 2:
        roots.append(parts[1].strip())
print("containers searched:", roots)

stores = []
for root in roots:
    for dirpath, _dirs, files in os.walk(root):
        if "AltStore.sqlite" in files:
            stores.append(os.path.join(dirpath, "AltStore.sqlite"))
print("stores found:", stores)
if not stores:
    print("no AltStore.sqlite: did pass A launch the app?")
    sys.exit(1)

db = stores[0]
con = sqlite3.connect(db)
cur = con.cursor()

entities = {name: (ent, mx) for ent, name, mx in cur.execute("SELECT Z_ENT, Z_NAME, Z_MAX FROM Z_PRIMARYKEY")}
print("Z_PRIMARYKEY Account:", entities.get("Account"), "Team:", entities.get("Team"))


def columns(table):
    return [row[1] for row in cur.execute("PRAGMA table_info(%s)" % table)]


for table in ("ZACCOUNT", "ZTEAM"):
    print(table, "columns:", columns(table))
print("teams before:", list(cur.execute("SELECT Z_PK, ZIDENTIFIER, ZNAME, ZISACTIVETEAM FROM ZTEAM")))
print("accounts before:", list(cur.execute("SELECT Z_PK, ZIDENTIFIER, ZISACTIVEACCOUNT FROM ZACCOUNT")))


def insert(table, entity, values):
    ent, mx = entities[entity]
    pk = (mx or 0) + 1
    row = {"Z_PK": pk, "Z_ENT": ent, "Z_OPT": 1}
    row.update(values)
    have = columns(table)
    missing = [name for name in row if name not in have]
    if missing:
        print("%s has no column(s) %s" % (table, missing))
        sys.exit(1)
    cur.execute("INSERT INTO %s (%s) VALUES (%s)" % (table, ", ".join(row), ", ".join("?" * len(row))),
                list(row.values()))
    cur.execute("UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_NAME = ?", (pk, entity))
    return pk


account = insert("ZACCOUNT", "Account", {
    "ZISACTIVEACCOUNT": 1,
    "ZAPPLEID": "simulator-test@example.invalid",
    "ZFIRSTNAME": "Simulator",
    "ZLASTNAME": "Test",
    "ZIDENTIFIER": "FMXSIMACCOUNT1",
})
team = insert("ZTEAM", "Team", {
    "ZISACTIVETEAM": 1,
    "ZTYPE": 1,  # ALTTeamTypeFree: Team.swift shows it as "Free Developer Account"
    "ZACCOUNT": account,
    "ZIDENTIFIER": "FMXSIMTEAM1",
    "ZNAME": "Simulator Test",
})
con.commit()
cur.execute("PRAGMA wal_checkpoint(TRUNCATE)")
print("teams after:", list(cur.execute("SELECT Z_PK, ZIDENTIFIER, ZNAME, ZTYPE, ZACCOUNT, ZISACTIVETEAM FROM ZTEAM")))
print("accounts after:", list(cur.execute("SELECT Z_PK, ZIDENTIFIER, ZAPPLEID, ZISACTIVEACCOUNT FROM ZACCOUNT")))
con.close()
print("seeded team %d on account %d in %s" % (team, account, db))
