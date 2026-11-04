"""Generate config/bastion-01.events: one morning of bastion-01's sshd log, in a fixed order.

Run from the lab directory: python3 tools/make_feed.py > config/bastion-01.events
The feed (config/feed.sh) prefixes each line with the current syslog timestamp.
"""
import random

r = random.Random(5715)
HOST = "bastion-01"
pid = [20000]


def line(msg):
    pid[0] += r.randint(1, 40)
    return "%s sshd[%d]: %s" % (HOST, pid[0], msg)


def port():
    return r.randint(32768, 60999)


def invalid(user, ip):
    p = port()
    return [line("Invalid user %s from %s port %d" % (user, ip, p)),
            line("Failed password for invalid user %s from %s port %d ssh2" % (user, ip, p))]


def failed(user, ip):
    return [line("Failed password for %s from %s port %d ssh2" % (user, ip, port()))]


def accepted(user, ip, method="publickey"):
    p = port()
    extra = ": RSA SHA256:%s" % "".join(r.choice("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789") for _ in range(43)) if method == "publickey" else ""
    return [line("Accepted %s for %s from %s port %d ssh2%s" % (method, user, ip, p, extra)),
            line("pam_unix(sshd:session): session opened for user %s(uid=%d) by (uid=0)" % (user, 1000 + sum(map(ord, user)) % 50))]


SPRAY = ["admin", "test", "oracle", "ubuntu", "pi", "guest", "user", "ftp", "postgres", "support",
         "git", "jenkins", "ansible", "hadoop", "minecraft", "test1", "administrator", "www", "dev", "backup"]
STAFF = ["mira", "tomas", "kenji", "ops"]

background = []
# Staff log in with keys all morning; one typo with a password
for _ in range(9):
    background.append(accepted(r.choice(STAFF), "10.20.0.%d" % r.randint(10, 40)))
background.append(failed("tomas", "10.20.0.17"))
background.append(failed("tomas", "10.20.0.17"))
# Two other internet scanners, invalid users only
for u in r.sample(SPRAY, 12):
    background.append(invalid(u, "198.51.100.14"))
for u in r.sample(SPRAY, 6):
    background.append(invalid(u, "192.0.2.88"))
r.shuffle(background)

attack = []
# The attacker: a spray of invalid names, then a real account, then the hit
for u in SPRAY + SPRAY[:6]:
    attack.append(invalid(u, "203.0.113.66"))
for _ in range(9):
    attack.append(failed("deploy", "203.0.113.66"))
attack.append(accepted("deploy", "203.0.113.66", "password"))

# Mix: background, the attack in the middle, then later the same password from a second address
out = background[:14] + attack + background[14:]
out += [accepted("mira", "10.20.0.21")]
out += [accepted("deploy", "198.51.100.230", "password")]
out += [accepted("ops", "10.20.0.33")]
for block in out:
    for l in block:
        print(l)
