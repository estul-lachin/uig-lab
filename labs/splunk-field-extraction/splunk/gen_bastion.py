#!/usr/bin/env python3
"""Generate bastion-01's sshd log for 2026-10-30 (UTC): the shop's SSH jump host. A compromised
internal machine sprays usernames, a botnet tries a few names each from many addresses, and staff
mistype now and then. Fixed seed."""
import random
from datetime import datetime, timedelta, timezone

R = random.Random(20261031)
DAY = datetime(2026, 10, 30, tzinfo=timezone.utc)
rows = []
def at(h=None):
    return DAY + timedelta(seconds=R.randrange(24 * 3600)) if h is None else DAY + timedelta(hours=h, seconds=R.randrange(3600))
def port(): return R.randrange(30000, 65000)
for _ in range(120):                               # staff log in normally
    rows.append((at(), f"Accepted publickey for {R.choice(['maya', 'omar', 'li'])} from 10.20.4.10 port {port()} ssh2"))
for _ in range(9):                                 # and mistype now and then
    rows.append((at(), f"Failed password for {R.choice(['maya', 'omar'])} from 10.20.4.10 port {port()} ssh2"))
for _ in range(85):                                # 10.30.5.17 was compromised and sprays from inside
    u = R.choice(["admin", "backup", "postgres", "git", "jenkins"])
    rows.append((at(13), f"Failed password for invalid user {u} from 10.30.5.17 port {port()} ssh2"))
botnet = [f"198.51.100.{n}" for n in range(150, 190)]
for ip in botnet:                                  # 40 addresses, 3 tries each
    for _ in range(3):
        rows.append((at(19), f"Failed password for invalid user {R.choice(['ubnt', 'pi', 'admin'])} from {ip} port {port()} ssh2"))
for _ in range(25):
    rows.append((at(), f"Connection closed by authenticating user root 203.0.113.9 port {port()} [preauth]"))
with open("/out/bastion-secure.log", "w") as f:
    for t, msg in sorted(rows):
        f.write(f'{t.strftime("%Y-%m-%dT%H:%M:%S.000000+00:00")} bastion-01 sshd[{R.randrange(800, 9000)}]: {msg}\n')
print(len(rows))
