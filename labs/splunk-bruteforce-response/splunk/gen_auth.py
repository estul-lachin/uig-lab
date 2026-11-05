"""Generate /out/secure.log: four days of bastion-01's sshd log (27-30 October 2026), fixed seed.

What is in it: staff logging in with keys from 10.20.0.0/16 (a few typos first), internet noise
against root/ubuntu/admin (often non-existent users), one loud brute force that gets in, one slow
one that gets in, and a password spray from 30 addresses of which one gets in.
"""
import random
from datetime import datetime, timedelta, timezone

R = random.Random(2026_10_30)
OUT = "/out"
START = datetime(2026, 10, 27, 0, 0, 0, tzinfo=timezone.utc)
SPAN = 4 * 86400
lines = []


def at(sec):
    return START + timedelta(seconds=sec)


def rand_t():
    return R.randrange(SPAN)


def add(sec, msg):
    lines.append((at(sec), msg))


def port():
    return R.randrange(32768, 61000)


def failed(sec, user, ip, invalid=False):
    add(sec, "Failed password for %s%s from %s port %d ssh2" % ("invalid user " if invalid else "", user, ip, port()))


def accepted(sec, user, ip, method="password"):
    add(sec, "Accepted %s for %s from %s port %d ssh2" % (method, user, ip, port()))


# Staff: keys from the office network, a couple of password typos before a password login
STAFF = ["mira", "tomas", "kenji", "ops", "lena"]
for _ in range(140):
    accepted(rand_t(), R.choice(STAFF), "10.20.%d.%d" % (R.randint(0, 3), R.randint(10, 60)), "publickey")
for user, ip in [("tomas", "10.20.0.17"), ("lena", "10.20.2.44")]:
    t = rand_t()
    for i in range(3):
        failed(t + i * 7, user, ip)
    accepted(t + 30, user, ip)

# Internet noise: 45 addresses, 5 to 30 guesses each, the usual names
for n in range(45):
    ip = "203.0.113.%d" % (100 + n) if n < 25 else "198.51.100.%d" % (150 + n)
    for _ in range(R.randint(5, 30)):
        user = R.choices(["root", "ubuntu", "admin", "test", "oracle", "pi"], [40, 20, 15, 8, 5, 4])[0]
        failed(rand_t(), user, ip, invalid=(user != "root"))

# 1. The loud one: 120 guesses at jenkins in 20 minutes, a login, and another one the next morning
LOUD = "198.51.100.73"
t0 = 2 * 86400 + 1 * 3600 + 12 * 60
for i in range(120):
    failed(t0 + i * 10, "jenkins", LOUD)
accepted(t0 + 1215, "jenkins", LOUD)
accepted(t0 + 1215 + 27000, "jenkins", LOUD)

# 2. The slow one: 24 guesses at deploy, one every 40 minutes, then in
SLOW = "203.0.113.88"
t1 = 86400 + 9 * 3600
for i in range(24):
    failed(t1 + i * 2400 + R.randint(0, 300), "deploy", SLOW)
accepted(t1 + 24 * 2400 + 600, "deploy", SLOW)

# 3. The spray: 30 addresses, 3 guesses each at backup, spread over a day; one of them gets in
SPRAY = ["192.0.2.%d" % (120 + i) for i in range(30)]
WINNER = SPRAY[17]
t2 = 3 * 86400
for ip in SPRAY:
    for _ in range(3):
        failed(t2 + R.randrange(80000), "backup", ip)
accepted(t2 + 82000, "backup", WINNER)

with open(OUT + "/secure.log", "w") as f:
    for t, msg in sorted(lines):
        f.write("%s bastion-01 sshd[%d]: %s\n" % (t.strftime("%Y-%m-%dT%H:%M:%S.000000+00:00"), R.randrange(1000, 60000), msg))
print(len(lines), "lines; spray winner", WINNER)
