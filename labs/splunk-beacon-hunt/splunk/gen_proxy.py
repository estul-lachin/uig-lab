"""Generate /out/proxy.log and /out/asn_lookup.csv: the web proxy's day, 4 November 2026 08:00-16:00 UTC.

In it: 24 workstations browsing in bursts, Windows telemetry from 20 of them every 2 minutes (as
regular as any implant), one implant on WS-ENG-14 calling home every 60 s on port 8443 (and once
getting a task), and a quieter one on WS-FIN-05 every 5 minutes with 25% jitter on 443.
Fixed seed: the same file every build.
"""
import random
from datetime import datetime, timedelta, timezone

R = random.Random(20261104)
OUT = "/out"
T0 = datetime(2026, 11, 4, 8, 0, 0, tzinfo=timezone.utc)
SPAN = 8 * 3600
HOSTS = ["10.60.%d.%d" % (1 + i // 8, 10 + i) for i in range(24)]
C2_SRC, C2, C2_HOST = HOSTS[12], "198.51.100.66", "cdn-static-assets.net"
JIT_SRC, JIT, JIT_HOST = "10.60.1.15", "203.0.113.77", "api.weather-widgets.io"
TEL, TEL_HOST = "192.0.2.40", "v10.events.data.microsoft.com"
SITES = [("www.wikipedia.org", "192.0.2.11"), ("github.com", "192.0.2.12"), ("docs.python.org", "192.0.2.13"),
         ("www.bbc.co.uk", "192.0.2.14"), ("outlook.office365.com", "192.0.2.15"), ("teams.microsoft.com", "192.0.2.16"),
         ("www.google.com", "192.0.2.17"), ("stackoverflow.com", "192.0.2.18"), ("slack.com", "192.0.2.19"),
         ("www.amazon.com", "192.0.2.20"), ("news.ycombinator.com", "192.0.2.21"), ("www.reddit.com", "192.0.2.22")]
ASN = {"192.0.2.11": ("AS64500", "Wiki Media Example"), "192.0.2.12": ("AS64501", "Code Hosting Example"),
       "192.0.2.13": ("AS64502", "Docs CDN Example"), "192.0.2.14": ("AS64503", "News Example"),
       "192.0.2.15": ("AS64504", "Microsoft Example"), "192.0.2.16": ("AS64504", "Microsoft Example"),
       "192.0.2.17": ("AS64505", "Search Example"), "192.0.2.18": ("AS64506", "QA Example"),
       "192.0.2.19": ("AS64507", "Chat Example"), "192.0.2.20": ("AS64508", "Retail Example"),
       "192.0.2.21": ("AS64509", "Forum Example"), "192.0.2.22": ("AS64510", "Social Example"),
       TEL: ("AS64504", "Microsoft Example"), C2: ("AS64511", "Quickhost Bulletproof Ltd"),
       JIT: ("AS64499", "Nightowl VPS SRL")}
UA = {"browser": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36",
      "tel": "Microsoft-Delivery-Optimization/10.1", "c2": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; Trident/7.0; rv:11.0) like Gecko"}
lines = []


def req(sec, src, host, ip, port, method, url, status, out, inn, ua):
    when = T0 + timedelta(seconds=sec)
    lines.append((when, '%s proxy-01 src_ip=%s dest_host=%s dest_ip=%s dest_port=%d method=%s url="%s" status=%d bytes_out=%d bytes_in=%d user_agent="%s"' % (
        when.strftime("%Y-%m-%dT%H:%M:%SZ"), src, host, ip, port, method, url, status, out, inn, ua)))


# Browsing: sessions of a few to a few dozen requests, seconds apart
for src in HOSTS:
    for _ in range(R.randint(10, 18)):
        sec = R.randrange(SPAN - 600)
        host, ip = R.choice(SITES)
        for _ in range(R.randint(3, 30)):
            sec += R.choice([0, 0, 1, 1, 2, 3, 5, 8, 20, 45])
            req(sec, src, host, ip, 443, R.choice(["GET"] * 5 + ["POST"]), "/" + R.choice(["", "index.html", "api/v2/items", "static/app.js", "search"]),
                R.choice([200] * 12 + [304, 404]), R.randint(300, 2000), R.randint(500, 400000), UA["browser"])

# Telemetry: 20 workstations, every 120 s, within a second
for src in HOSTS[:20]:
    sec = R.randrange(120)
    while sec < SPAN:
        req(sec, src, TEL_HOST, TEL, 443, "POST", "/OneCollector/1.0/", 200, R.randint(1100, 1300), R.randint(90, 110), UA["tel"])
        sec += 120 + R.choice([-1, 0, 0, 1])

# The implant: every 60 s (+-2 s), small check-ins, one task at 11:42
sec = 37
while sec < SPAN:
    when = T0 + timedelta(seconds=sec)
    task = when.hour == 11 and when.minute == 42
    after = when.hour == 11 and when.minute in (43, 44)
    req(sec, C2_SRC, C2_HOST, C2, 8443, "POST", "/jquery-3.7.1.min.js", 200,
        R.randint(52000, 61000) if after else R.randint(180, 220), 48211 if task else R.randint(200, 260), UA["c2"])
    sec += 60 + R.randint(-2, 2)

# The quiet one: every 300 s with 25% jitter, on 443
sec = 610
while sec < SPAN:
    req(sec, JIT_SRC, JIT_HOST, JIT, 443, "GET", "/v1/forecast?id=%d" % R.randint(1000, 9999), 200, R.randint(240, 300), R.randint(310, 360), UA["browser"])
    sec += int(300 * R.uniform(0.75, 1.25))

with open(OUT + "/proxy.log", "w") as f:
    for when, line in sorted(lines):
        f.write(line + "\n")
with open(OUT + "/asn_lookup.csv", "w") as f:
    f.write("ip,asn,org\n")
    for ip, (asn, org) in sorted(ASN.items()):
        f.write("%s,%s,%s\n" % (ip, asn, org))
print(len(lines), "proxy lines")
