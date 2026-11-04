"""Write case/security.jsonl: RDP logons on BWD-FS01 the day of a fictional REvil-style hit.
Deterministic. Descriptive only. Usage: python3 tools/make_security.py > case/security.jsonl
"""
import json
import random
from datetime import datetime, timedelta

rnd = random.Random(2021)
T = datetime(2026, 6, 1, 0, 0, 0)
ev = []
def add(m, eid, **f):
    ev.append({"TimeCreated": (T + timedelta(seconds=int(m * 60))).strftime("%Y-%m-%dT%H:%M:%SZ"), "Computer": "BWD-FS01", "EventID": eid, **f})
for _ in range(60):
    m = rnd.uniform(13 * 60, 23 * 60); u = rnd.choice(["dr.ames", "front.desk", "billing", "it.contractor"])
    add(m, 4624, TargetUserName=u, IpAddress="10.70.0.%d" % rnd.randint(20, 60), LogonType=rnd.choice([3, 3, 10]))
for i in range(5): add(9 * 60 + i, 4625, TargetUserName="front.desk", IpAddress="10.70.0.31", LogonType=10)
names = ["administrator", "admin", "scan", "backup", "reception", "test", "user", "dentist", "xray"]
for i in range(1400):
    add(20 * 60 + i * 0.08, 4625, TargetUserName=names[i % len(names)], IpAddress="198.51.100.66", LogonType=10)
for i in range(300):   # a second, unrelated scanner that never gets in
    add(20 * 60 + 10 + i * 0.2, 4625, TargetUserName=names[(i * 7) % len(names)], IpAddress="203.0.113.19", LogonType=10)
add(21 * 60 + 58, 4624, TargetUserName="xray", IpAddress="198.51.100.66", LogonType=10)
add(22 * 60 + 41, 4688, SubjectUserName="xray", NewProcessName="C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
    CommandLine="powershell -e RwBlAHQALQBXAG0AaQBPAGIAagBlAGMAdAAgAFcAaQBuADMAMgBfAFMAaABhAGQAbwB3AGMAbwBwAHkAIAB8ACAARgBvAHIARQBhAGMAaAAtAE8AYgBqAGUAYwB0ACAAewAkAF8ALgBEAGUAbABlAHQAZQAoACkAOwB9AA==")
add(22 * 60 + 46, 4688, SubjectUserName="xray", NewProcessName="C:\\Users\\xray\\AppData\\Local\\Temp\\svc0601.exe", CommandLine="svc0601.exe -nolan -silent")
ev.sort(key=lambda e: e["TimeCreated"])
for i, e in enumerate(ev, start=1):
    print(json.dumps({"RecordID": 70000 + i, **e}, separators=(",", ":")))
