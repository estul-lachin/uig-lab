# Checks for ownership-groups (see templates/lab/check.sh for the rules).

_in() { id -nG "$1" 2>/dev/null | tr " " "\n" | grep -qx "$2"; }
N=/srv/shared/notes.txt

section "1. Group devs"
check "Group devs exists with GID 3000" '[ "$(getent group devs | cut -d: -f3)" = 3000 ]' "groupadd -g 3000 devs"

section "2. Members"
check "alice exists with her own primary group" 'id alice && [ "$(id -gn alice)" = alice ]' "useradd -m alice keeps a personal primary group"
check "alice is in devs (supplementary)" '_in alice devs' "usermod -aG devs alice"
check "bob is no longer in devs" 'getent group devs && id bob && ! _in bob devs' "gpasswd -d bob devs"
check "bob is still in ops" '_in bob ops' "Removing him from devs must not touch his other groups"

section "3. Shared file"
check "notes.txt is group devs, mode 660" '[ "$(stat -c %G:%a $N 2>/dev/null)" = devs:660 ]' "chgrp devs; chmod 660"
check "alice can write to it" '[ -f $N ] && as_user alice "echo hi >> $N"' "Group rw via devs"
check "carol cannot read it" '[ -f $N ] && id carol && ! as_user carol "cat $N"' "Others get nothing"

section "4. Recursive chown, safely"
check "Everything under /srv/shared is root:devs" 'getent group devs && [ -f /srv/shared/notes.txt ] && [ -z "$(find /srv/shared ! \( -user root -group devs \) -print -quit 2>&1)" ]' \
  "chown -R root:devs /srv/shared (the link itself counts too)"
check "/etc/shadow is still root:shadow" '[ "$(stat -c %U:%G /etc/shadow)" = root:shadow ]' \
  "chown on a glob or with -L follows symlinks. If it changed, put it back with chgrp shadow /etc/shadow"
check "The planted link is identified" '[ "$(sed -n "s/^PLANTED_LINK=//p" /root/answers.txt 2>/dev/null)" = /srv/shared/specs/v2/latest ]' \
  "find /srv/shared -type l, then ls -l to see where it points"
check "...and removed" '[ -d /srv/shared/specs/v2 ] && [ ! -L /srv/shared/specs/v2/latest ]' "rm the link (rm on a link removes the link, not the target)"

section "5. Orphaned files"
check "/root/orphans.txt lists the files without an owner" '[ "$(sort /root/orphans.txt 2>/dev/null | grep .)" = "$(printf "%s\n" /opt/legacy-tool/run.sh /var/archive/q1-export.csv /var/archive/q2-export.csv)" ]' \
  "find / -xdev \( -nouser -o -nogroup \) 2>/dev/null, sorted"
check "No file on / is left without an owner or group" '[ -f /var/archive/q1-export.csv ] && [ -z "$(find / -xdev \( -nouser -o -nogroup \) -print -quit 2>/dev/null)" ]' \
  "chown root:root them; don't delete them"
