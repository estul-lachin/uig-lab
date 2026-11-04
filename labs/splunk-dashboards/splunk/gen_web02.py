#!/usr/bin/env python3
"""Generate web-02's access log for 2026-10-30 (UTC): the shop's second web server behind the load
balancer, with a 20-minute outage (503) and a WAF blocking three attackers (403). Fixed seed."""
import random
from datetime import datetime, timedelta, timezone

R = random.Random(20261030)
DAY = datetime(2026, 10, 30, tzinfo=timezone.utc)
CLIENTS = [f"10.20.{R.randrange(1, 9)}.{R.randrange(2, 250)}" for _ in range(25)]
PAGES = ["/", "/menu", "/order", "/order/confirm", "/api/cart", "/api/stock", "/login", "/static/app.js"]
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/129.0 Safari/537.36"
rows = []
def add(t, ip, meth, path, st, ua=UA):
    rows.append((t, ip, meth, path, st, R.randrange(180, 24000) if st == 200 else R.randrange(150, 900), ua))

for _ in range(900):                                   # a normal day
    t = DAY + timedelta(seconds=R.randrange(24 * 3600))
    if datetime(2026, 10, 30, 10, 0, tzinfo=timezone.utc) <= t < datetime(2026, 10, 30, 10, 20, tzinfo=timezone.utc):
        continue
    meth = "POST" if R.random() < 0.22 else "GET"
    st = R.choices([200, 302, 304, 404], weights=[86, 5, 6, 3])[0]
    add(t, R.choice(CLIENTS), meth, R.choice(PAGES), st)
for _ in range(160):                                   # 10:00-10:20 the app pool is down
    t = datetime(2026, 10, 30, 10, 0, tzinfo=timezone.utc) + timedelta(seconds=R.randrange(20 * 60))
    add(t, R.choice(CLIENTS), "POST" if R.random() < 0.3 else "GET", R.choice(PAGES), 503)
for ip, n, path in [("203.0.113.71", 45, "/login?user=admin'--"), ("203.0.113.72", 30, "/api/cart?id=1%20OR%201=1"),
                    ("198.51.100.140", 18, "/order/../../etc/passwd")]:
    for _ in range(n):                                 # the WAF answers 403
        t = DAY + timedelta(hours=14) + timedelta(seconds=R.randrange(3 * 3600))
        add(t, ip, R.choice(["GET", "POST"]), path, 403, "sqlmap/1.8")
with open("/out/web02-access.log", "w") as f:
    for t, ip, meth, path, st, size, ua in sorted(rows):
        f.write(f'{ip} - - [{t.strftime("%d/%b/%Y:%H:%M:%S +0000")}] "{meth} {path} HTTP/1.1" {st} {size} "-" "{ua}"\n')
print(len(rows))
