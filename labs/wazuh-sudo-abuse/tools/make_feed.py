"""Write config/web-server-01.events: one afternoon of sudo activity on web-server-01, without
timestamps (the feeder adds the time as it writes each line). The order matters: Wazuh calls a
user's first successful sudo rule 5403 and later ones 5402. Deterministic.
Usage: python3 tools/make_feed.py > config/web-server-01.events
"""
import random

R = random.Random(5402)
def sudo(user, cmd, target="root", fail=None, tty="pts/1"):
    head = f"web-server-01 sudo: {user:>8} : "
    if fail == 1:
        head += "1 incorrect password attempt ; "
    elif fail == 3:
        head += "3 incorrect password attempts ; "
    elif fail == "denied":
        head += "command not allowed ; "
    return head + f"TTY={tty} ; PWD=/home/{user} ; USER={target} ; COMMAND={cmd}"

lines = []
admin_cmds = ["/usr/bin/systemctl restart nginx", "/usr/bin/journalctl -u nginx --since today", "/usr/bin/apt-get update",
              "/usr/bin/systemctl reload php8.3-fpm", "/usr/bin/tail -n 50 /var/log/nginx/error.log", "/usr/sbin/nginx -t"]
noise = []
for _ in range(34):
    noise.append(sudo(R.choice(["sarah", "li"]), R.choice(admin_cmds), tty=R.choice(["pts/2", "pts/3"])))
for _ in range(12):
    noise.append(sudo("backup-bot", "/usr/bin/rsync -a /var/www/ /srv/backup/www/", tty="unknown"))
for _ in range(6):
    noise.append(sudo("sarah", "/usr/bin/ls -la /var/www/shop", target="www-data", tty="pts/2"))
noise.append(sudo("li", "/usr/bin/apt-get upgrade -y", fail=1, tty="pts/3"))
for _ in range(4):
    noise.append(sudo("tomas", "/usr/bin/systemctl status nginx", fail=1, tty="pts/4"))

abuse = []
probe = ["/bin/bash", "/usr/bin/su -", "/usr/bin/cat /etc/shadow", "/usr/bin/passwd root", "/usr/bin/visudo"]
for _ in range(23):
    abuse.append(sudo("dkim", R.choice(probe), fail=1))
for _ in range(3):
    abuse.append(sudo("dkim", R.choice(probe), fail=3))
for c in ["/bin/bash", "/usr/bin/su -", "/usr/bin/cat /etc/shadow", "/usr/bin/python3"]:
    abuse.append(sudo("dkim", c, fail="denied"))

# Interleave the probing into the normal afternoon, then the breakthrough and what follows
R.shuffle(noise)
mixed = noise[:]
for i, a in enumerate(abuse):
    mixed.insert(min(len(mixed), 8 + i * 2), a)
mixed.append(sudo("dkim", "/usr/bin/vim /etc/nginx/nginx.conf"))
mixed.append("web-server-01 useradd[2210]: new user: name=sysupd, UID=0, GID=0, home=/home/sysupd, shell=/bin/bash, from=/dev/pts/1")
mixed.append(sudo("dkim", "/usr/bin/vim /etc/nginx/nginx.conf"))
mixed.append(sudo("sarah", "/usr/bin/systemctl restart nginx", tty="pts/2"))
print("\n".join(mixed))
