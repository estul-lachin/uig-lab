"""Write case/conn.log, case/dns.log and case/inventory.csv: a fictional WannaCry-style worm outbreak at
Alder Valley Water (AVW), as Zeek-style logs. Deterministic: the same files every run.
Descriptive only: connection and DNS records, no tooling. Usage: python3 tools/make_logs.py case/
"""
import random
import sys
from datetime import datetime, timezone

OUT = sys.argv[1].rstrip("/")
rnd = random.Random(1310)
T0 = datetime(2026, 5, 12, 9, 0, 0, tzinfo=timezone.utc).timestamp()
KILL = "qzvxkwpcuemtgrbhfsnaojyd-update.example"      # the variant's kill-switch domain (fictional)
SINKHOLE_AT = T0 + 5 * 60                              # a researcher registers it at 09:05
SINK_IP = "198.51.100.200"

servers = ["10.60.2.%d" % i for i in (10, 11, 15, 20, 21, 30)]
works = ["10.60.1.%d" % i for i in range(21, 61)]
ot = ["10.60.3.%d" % i for i in (5, 6, 7)]          # plant network: 445 blocked from the office by the firewall
names = {}
for ip in servers: names[ip] = "AVW-SRV%02d" % int(ip.split(".")[-1])
for ip in works: names[ip] = "AVW-WS%03d" % int(ip.split(".")[-1])
for ip in ot: names[ip] = "AVW-HMI%02d" % int(ip.split(".")[-1])
# Patch state: MS17-010 missing on these (SMBv1 on, too)
unpatched = set(["10.60.2.15", "10.60.2.21"] + rnd.sample(works, 17) + ["10.60.3.5", "10.60.3.6"])

conn, dns = [], []
uid = [0]
def c(t, src, sp, dst, dp, state, ob, rb, proto="tcp"):
    uid[0] += 1
    conn.append((t, "C%06d" % uid[0], src, sp, dst, dp, proto, state, ob, rb))
def q(t, src, name, rcode, ans):
    dns.append((t, src, name, rcode, ans))

# background traffic all morning
everyone = servers + works + ot
for _ in range(2500):
    t = T0 + rnd.uniform(0, 3 * 3600); s = rnd.choice(works)
    d, p = rnd.choice([("10.60.2.10", 445), ("10.60.2.11", 443), ("10.60.2.20", 389), ("192.0.2.80", 443), ("10.60.2.30", 53)])
    c(t, s, rnd.randint(49152, 65000), d, p, "SF", rnd.randint(200, 90000), rnd.randint(200, 900000))
for _ in range(300):
    t = T0 + rnd.uniform(0, 3 * 3600); s = rnd.choice(works)
    q(t, s, rnd.choice(["portal.avw.example", "mail.avw.example", "updates.example.org"]), "NOERROR", "192.0.2.%d" % rnd.randint(10, 99))

infected = {}       # ip -> time it was exploited
def exploit(t, src, dst):
    c(t, src, rnd.randint(49152, 65000), dst, 445, "SF", 4600 + rnd.randint(0, 900), 1100 + rnd.randint(0, 200))
    if dst not in infected:
        infected[dst] = t

# 09:02 the worm arrives from the internet at the one server with 445 exposed
c(T0 + 120, "203.0.113.130", 50112, "10.60.2.15", 445, "SF", 5120, 1240)
infected["10.60.2.15"] = T0 + 120
encrypted, stopped = [], []
queue = ["10.60.2.15"]
done = set()
while queue:
    queue.sort(key=lambda ip: infected[ip])
    h = queue.pop(0)
    if h in done: continue
    done.add(h)
    t = infected[h] + rnd.uniform(20, 60)
    if t >= SINKHOLE_AT:
        q(t, h, KILL, "NOERROR", SINK_IP); stopped.append(h); continue
    q(t, h, KILL, "NXDOMAIN", "-"); encrypted.append(h)
    # scan: a few targets per minute, local /24 first, then the other office /24
    targets = [x for x in everyone if x != h]
    rnd.shuffle(targets)
    tt = t + 5
    for d in targets[:rnd.randint(14, 26)]:
        tt += rnd.uniform(2, 9)
        if d in ot:
            c(tt, h, rnd.randint(49152, 65000), d, 445, "S0", 0, 0)        # dropped by the plant firewall
        elif d in unpatched:
            exploit(tt, h, d)
            if d not in done and d not in queue: queue.append(d)
        elif d in servers and d != "10.60.2.15" or d in works:
            c(tt, h, rnd.randint(49152, 65000), d, 445, rnd.choice(["REJ", "RSTO"]) if rnd.random() < 0.3 else "SF", 180, 120)
    # it also tries random internet addresses
    for _ in range(rnd.randint(5, 12)):
        tt += rnd.uniform(1, 5)
        c(tt, h, rnd.randint(49152, 65000), "203.0.113.%d" % rnd.randint(1, 254), 445, "S0", 0, 0)

conn.sort(); dns.sort()
with open(OUT + "/conn.log", "w") as f:
    f.write("#fields\tts\tuid\tid.orig_h\tid.orig_p\tid.resp_h\tid.resp_p\tproto\tconn_state\torig_bytes\tresp_bytes\n")
    for r in conn:
        f.write("%.3f\t%s\t%s\t%d\t%s\t%d\t%s\t%s\t%d\t%d\n" % r)
with open(OUT + "/dns.log", "w") as f:
    f.write("#fields\tts\tid.orig_h\tquery\trcode_name\tanswers\n")
    for r in dns:
        f.write("%.3f\t%s\t%s\t%s\t%s\n" % r)
with open(OUT + "/inventory.csv", "w") as f:
    f.write("ip,hostname,os,ms17_010\n")
    for ip in sorted(everyone, key=lambda x: tuple(int(p) for p in x.split("."))):
        os_ = "Windows Server 2012 R2" if ip in servers else ("Windows 7 Embedded" if ip in ot else rnd.choice(["Windows 7 SP1", "Windows 10 1607"]))
        f.write("%s,%s,%s,%s\n" % (ip, names[ip], os_, "missing" if ip in unpatched else "installed"))
print("encrypted", len(encrypted), "stopped", len(stopped), "unpatched", len(unpatched),
      "unpatched-never-hit", sorted(u for u in unpatched if u not in infected), file=sys.stderr)
