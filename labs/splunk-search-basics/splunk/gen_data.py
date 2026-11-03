#!/usr/bin/env python3
"""Generate the lab's log data: four sourcetypes from 2026-10-26 to 2026-10-30 (UTC), with one bad night
on 2026-10-29. Fixed seed, so every build produces the same events."""
import json
import random
from datetime import datetime, timedelta, timezone

R = random.Random(20261029)
START = datetime(2026, 10, 26, tzinfo=timezone.utc)
SPAN = 5 * 24 * 3600
OUT = "/out"

def t_rand(start=START, span=SPAN):
    return start + timedelta(seconds=R.randrange(span))

def t_burst(h, m, minutes):
    return datetime(2026, 10, 29, h, m, tzinfo=timezone.utc) + timedelta(seconds=R.randrange(minutes * 60))

SCANNER = "198.51.100.77"
BRUTE = "203.0.113.50"
CLIENTS = [f"10.20.{R.randrange(1, 9)}.{R.randrange(2, 250)}" for _ in range(30)] + \
          [f"192.0.2.{R.randrange(2, 250)}" for _ in range(12)]
PAGES = ["/", "/menu", "/menu/specials", "/order", "/order/confirm", "/contact", "/about",
         "/static/app.js", "/static/style.css", "/img/logo.png", "/api/stock", "/api/cart"]
AGENTS = ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/129.0 Safari/537.36",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15",
          "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148"]

# ---- access_combined: shop web server
web = []
for _ in range(3600):
    status = R.choices([200, 301, 304, 404, 500], weights=[80, 4, 10, 5, 1])[0]
    web.append((t_rand(), R.choice(CLIENTS), "GET" if R.random() < 0.85 else "POST", R.choice(PAGES), status,
                R.randrange(300, 40000), R.choice(AGENTS)))
for _ in range(240):  # the scanner, 03:00-03:30 on the 29th
    path = R.choice(["/wp-login.php", "/wp-login.php", "/.env", "/phpmyadmin/", "/admin/config.php", "/.git/HEAD"])
    web.append((t_burst(3, 0, 30), SCANNER, "GET", path, R.choice([404, 404, 403]), R.randrange(150, 600),
                "Mozilla/5.0 zgrab/0.x"))
with open(f"{OUT}/access.log", "w") as f:
    for t, ip, meth, path, st, size, ua in sorted(web):
        f.write(f'{ip} - - [{t.strftime("%d/%b/%Y:%H:%M:%S +0000")}] "{meth} {path} HTTP/1.1" {st} {size} '
                f'"-" "{ua}"\n')

# ---- linux_secure: sshd and sudo on the same host
sec = []
for _ in range(160):
    t = t_rand(); user = R.choice(["maya", "omar", "deploy"])
    sec.append((t, "sshd", f"Accepted publickey for {user} from 10.20.4.10 port {R.randrange(40000, 60000)} ssh2"))
    sec.append((t + timedelta(seconds=1), "sshd", f"pam_unix(sshd:session): session opened for user {user}(uid=1001) by (uid=0)"))
for ip, n, start in [(BRUTE, 420, (2, 10)), ("192.0.2.200", 35, None), ("198.51.100.9", 14, None)]:
    for _ in range(n):
        t = t_burst(start[0], start[1], 30) if start else t_rand()
        user = R.choice(["root", "admin", "ubuntu", "test", "oracle"])
        sec.append((t, "sshd", f"Failed password for {user} from {ip} port {R.randrange(30000, 65000)} ssh2"))
sec.append((datetime(2026, 10, 29, 2, 41, 3, tzinfo=timezone.utc), "sshd",
            f"Accepted password for deploy from {BRUTE} port 51022 ssh2"))
sec.append((datetime(2026, 10, 29, 2, 42, 10, tzinfo=timezone.utc), "sudo",
            "deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/bash"))
with open(f"{OUT}/secure.log", "w") as f:
    for t, prog, msg in sorted(sec):
        f.write(f'{t.strftime("%Y-%m-%dT%H:%M:%S.000000+00:00")} web-01 {prog}[{R.randrange(800, 9000)}]: {msg}\n')

# ---- suricata: IDS alerts in eve JSON
sigs = [(2008578, "ET SCAN Suspicious inbound to mySQL port 3306", 2), (2210051, "SURICATA STREAM Packet with broken ack", 3),
        (2013028, "ET POLICY curl User-Agent Outbound", 3), (2001219, "ET SCAN Potential SSH Scan", 2)]
ids = []
for _ in range(90):
    sid, sig, sev = R.choice(sigs)
    ids.append((t_rand(), R.choice(CLIENTS[30:]), "10.20.0.5", sid, sig, sev))
for _ in range(40):
    ids.append((t_burst(3, 0, 30), SCANNER, "10.20.0.5", 2011716, "ET SCAN Possible WordPress login scan", 1))
for _ in range(25):
    ids.append((t_burst(2, 10, 30), BRUTE, "10.20.0.5", 2001219, "ET SCAN Potential SSH Scan", 2))
with open(f"{OUT}/eve.json", "w") as f:
    for t, src, dst, sid, sig, sev in sorted(ids):
        f.write(json.dumps({"timestamp": t.strftime("%Y-%m-%dT%H:%M:%S.%f+0000"), "event_type": "alert",
                            "src_ip": src, "dest_ip": dst, "proto": "TCP",
                            "alert": {"signature_id": sid, "signature": sig, "severity": sev}}) + "\n")

# ---- syslog: everyday system noise
sysl = []
for _ in range(500):
    prog, msg = R.choice([("CRON", "(root) CMD (/usr/local/bin/backup.sh)"), ("systemd", "Started Daily apt download activities."),
                          ("systemd", "logrotate.service: Deactivated successfully."), ("kernel", "eth0: link up"),
                          ("CRON", "(www-data) CMD (php /var/www/shop/cron.php)")])
    sysl.append((t_rand(), prog, msg))
with open(f"{OUT}/syslog.log", "w") as f:
    for t, prog, msg in sorted(sysl):
        f.write(f'{t.strftime("%Y-%m-%dT%H:%M:%S.000000+00:00")} web-01 {prog}[{R.randrange(100, 9000)}]: {msg}\n')
