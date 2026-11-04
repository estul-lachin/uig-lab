#!/usr/bin/env python3
"""Generate web-03's access log for 2026-10-30 (UTC): the shop's admin portal. An uptime monitor
polls it all day, staff use it, a WAF blocks three attackers, and one visitor makes two quiet requests
that get through. Fixed seed."""
import random
from datetime import datetime, timedelta, timezone

R = random.Random(20261101)
DAY = datetime(2026, 10, 30, tzinfo=timezone.utc)
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15"
rows = []
def add(t, ip, meth, path, st, ua=UA, size=None):
    rows.append((t, ip, meth, path, st, size or (R.randrange(400, 30000) if st == 200 else R.randrange(150, 900)), ua))

for m in range(0, 24 * 60, 2):                     # the uptime monitor, every 2 minutes
    add(DAY + timedelta(minutes=m, seconds=R.randrange(5)), "10.20.9.9", "GET", "/healthz", 200, "uptime-probe/2.1", 18)
staff = ["10.20.3.14", "10.20.3.22", "10.20.5.31", "10.20.6.40"]
for _ in range(260):                               # staff at work
    t = DAY + timedelta(hours=13, seconds=R.randrange(9 * 3600))
    add(t, R.choice(staff), R.choice(["GET", "GET", "POST"]), R.choice(["/admin/", "/admin/orders", "/admin/stock",
        "/admin/reports", "/admin/users"]), R.choices([200, 302, 500, 502], weights=[88, 8, 3, 1])[0])
for ip, n, path in [("203.0.113.81", 58, "/admin/login?u=admin'--"), ("203.0.113.82", 24, "/admin/../../etc/passwd"),
                    ("198.51.100.141", 11, "/admin/upload.php")]:
    for _ in range(n):                             # the WAF answers 403
        add(DAY + timedelta(hours=2, seconds=R.randrange(4 * 3600)), ip, "GET", path, 403, "python-requests/2.32")
# two quiet requests that the WAF does not catch, and that work
add(datetime(2026, 10, 30, 3, 17, 42, tzinfo=timezone.utc), "192.0.2.199", "GET", "/.git/config", 200, UA, 312)
add(datetime(2026, 10, 30, 3, 19, 5, tzinfo=timezone.utc), "192.0.2.199", "GET", "/backup/shop-db-2026-10.sql.gz", 200, UA, 48211830)
with open("/out/web03-access.log", "w") as f:
    for t, ip, meth, path, st, size, ua in sorted(rows):
        f.write(f'{ip} - - [{t.strftime("%d/%b/%Y:%H:%M:%S +0000")}] "{meth} {path} HTTP/1.1" {st} {size} "-" "{ua}"\n')
print(len(rows))
