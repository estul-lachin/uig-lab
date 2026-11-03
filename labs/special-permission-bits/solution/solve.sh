# Reference solution for special-permission-bits.
set -euo pipefail

# 1. SUID: a copy of id shows the effective UID it runs with
install -m 4755 -o root -g root /usr/bin/id /usr/local/bin/whoami-root
euid=$(su guest -s /bin/sh -c /usr/local/bin/whoami-root | grep -o 'euid=[^ ]*' | cut -d= -f2)
printf '#!/bin/sh\nid -u\n' > /usr/local/bin/suid-script.sh
chmod 4755 /usr/local/bin/suid-script.sh
[ "$(su guest -s /bin/sh -c /usr/local/bin/suid-script.sh)" = 0 ] && works=yes || works=no
rm -f /usr/local/bin/suid-script.sh

# 2. SGID directory
mkdir -p /srv/projects
chown root:devs /srv/projects
chmod 2770 /srv/projects

# 3. Sticky directory
mkdir -p /srv/dropbox
chmod 1777 /srv/dropbox

# 5. The backdoor (found with dpkg -S), then remove it and the demo binary
rogue=""
for f in $(find /usr -xdev -perm -4000 -type f); do
  dpkg -S "$f" >/dev/null 2>&1 || { [ "$f" = /usr/local/bin/whoami-root ] || rogue=$f; }
done
cmp -s "$rogue" /usr/bin/find && what=find || what=unknown
{
  echo "WHOAMI_EUID=$euid"
  echo "SCRIPT_SUID_WORKS=$works"
  echo "ROGUE_SUID=$rogue"
  echo "ROGUE_IS=$what"
} > /root/answers.txt
rm -f "$rogue" /usr/local/bin/whoami-root

# 4. SUID audit, on the final state
find /usr -xdev -perm -4000 -type f | sort > /root/suid_list.txt
wc -l < /root/suid_list.txt > /root/suid_count.txt
