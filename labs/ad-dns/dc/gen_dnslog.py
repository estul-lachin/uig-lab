# Writes the DC's DNS query log for 5 November 2026, 08:00 to 12:00 UTC (deterministic).
# Line format: <time> <client> <qtype> <qname> <rcode> [<answer>]
import base64, random, sys
from datetime import datetime, timedelta, timezone

rnd = random.Random(20261105)
NET = "10.203.17."
START = datetime(2026, 11, 5, 8, 0, 0, tzinfo=timezone.utc)
END = START + timedelta(hours=4)
PLANTED = datetime(2026, 11, 5, 9, 41, 7, tzinfo=timezone.utc)
ROGUE = NET + "66"
TUNNEL = NET + "57"   # ws-0107
clients = [NET + str(50 + i) for i in range(1, 9)]
internal = {"rdg-fs01.ridgeline.local": NET + "21", "rdg-sql01.ridgeline.local": NET + "22",
            "rdg-print01.ridgeline.local": NET + "23", "dc01.ridgeline.local": NET + "10",
            "intranet.ridgeline.local": NET + "21"}
public = ["www.microsoft.com", "login.microsoftonline.com", "outlook.office365.com", "teams.microsoft.com",
          "www.google.com", "fonts.googleapis.com", "github.com", "api.github.com", "www.wikipedia.org",
          "slack.com", "zoom.us", "www.bing.com", "ctldl.windowsupdate.com", "settings-win.data.microsoft.com"]
srv = ["_ldap._tcp.ridgeline.local", "_kerberos._tcp.ridgeline.local",
       "_ldap._tcp.dc._msdcs.ridgeline.local", "_ldap._tcp.Default-First-Site-Name._sites.ridgeline.local"]
rows = []
def add(t, c, qt, qn, rc, ans=""):
    rows.append((t, c, qt, qn, rc, ans))
def pubip():
    return "198.51.100.%d" % rnd.randint(2, 250)

t = START
while t < END:
    t += timedelta(seconds=rnd.randint(1, 9))
    c = rnd.choice(clients)
    r = rnd.random()
    if r < 0.45:
        add(t, c, "A", rnd.choice(public), "NOERROR", pubip())
    elif r < 0.70:
        n = rnd.choice(list(internal)); add(t, c, "A", n, "NOERROR", internal[n])
    elif r < 0.82:
        add(t, c, "SRV", rnd.choice(srv), "NOERROR", "dc01.ridgeline.local:389")
    elif r < 0.88:
        add(t, c, "AAAA", rnd.choice(public), "NOERROR", "2001:db8::%x" % rnd.randint(1, 4000))
    elif r < 0.92:
        add(t, c, "A", "wpad.ridgeline.local", *(("NOERROR", ROGUE) if t >= PLANTED else ("NXDOMAIN", "")))
    else:
        add(t, c, "A", "%s.ridgeline.local" % rnd.choice(["printer2", "old-share", "nas"]), "NXDOMAIN")

# ws-0107 smuggles a file out in TXT queries: 10:12 to 10:31, base32 chunks under one domain.
secret = bytes(rnd.getrandbits(8) for _ in range(5200))
chunks = base64.b32encode(secret).decode().rstrip("=").lower()
t = datetime(2026, 11, 5, 10, 12, 4, tzinfo=timezone.utc)
for i in range(0, len(chunks), 52):
    t += timedelta(milliseconds=rnd.randint(600, 1400))
    add(t, TUNNEL, "TXT", "%s.%04d.sync-telemetry.example" % (chunks[i:i + 52], i // 52), "NOERROR", '"ok"')

rows.sort()
with open(sys.argv[1], "w") as f:
    for t, c, qt, qn, rc, ans in rows:
        f.write(" ".join(x for x in (t.strftime("%Y-%m-%dT%H:%M:%SZ"), c, qt, qn, rc, ans) if x) + "\n")
