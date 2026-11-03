# Checks for linux-101-capstone (see templates/lab/check.sh for the rules).

S=/root/site
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }

section "1. Directory layout"
check "$S has public, scripts, backups and logs" 'for d in public scripts backups logs; do [ -d $S/$d ] || exit 1; done' \
  "mkdir -p /root/site/{public,scripts,backups,logs}"

section "2. index.html"
check "public/index.html says 'Welcome to Harbor Food Bank'" '[ -f $S/public/index.html ] && [ "$(cat $S/public/index.html)" = "Welcome to Harbor Food Bank" ]' \
  "echo ... > /root/site/public/index.html"

section "3. Permissions"
check "scripts/ is mode 750" '[ "$(stat -c %a $S/scripts 2>/dev/null)" = 750 ]' "chmod 750"

section "4. Hidden file"
check "deploy.conf is a copy of the hidden settings file" '[ -f $S/deploy.conf ] && cmp -s $S/deploy.conf /var/lib/harbor/.cache/old/.deploy-settings.conf' \
  "find / -name \"*deploy*\" -type f 2>/dev/null, then cp it to /root/site/deploy.conf"
check "The original is still in place" '[ -f $S/deploy.conf ] && [ -f /var/lib/harbor/.cache/old/.deploy-settings.conf ]' "Copy, don't move"

section "5. Backup script"
B=$S/scripts/backup.sh
check "backup.sh exists, is executable and has a shebang" '[ -x $B ] && head -n1 $B | grep -q "^#!"' "#!/bin/bash on line 1, then chmod +x"
check "It has produced backups/site.tar.gz" '[ -f $S/backups/site.tar.gz ]' "Run the script once"
check "The archive contains public/index.html" 'tar tzf $S/backups/site.tar.gz 2>/dev/null | grep -q "public/index.html$"' \
  "tar czf /root/site/backups/site.tar.gz -C /root/site public"

section "6. User webadmin"
check "webadmin exists with a home directory" 'id webadmin && [ -d /home/webadmin ]' "useradd -m webadmin"
check "webadmin is in group webteam" 'id -nG webadmin | tr " " "\n" | grep -qx webteam' "groupadd -f webteam; usermod -aG webteam webadmin"

section "7. IP address"
check "ip.txt holds this host's IPv4 address" '[ -f $S/ip.txt ] && [ "$(tr -d "[:space:]" < $S/ip.txt)" = "$(hostname -I | awk "{print \$1}")" ]' \
  "hostname -I, or ip -4 addr show"

section "8. Cron job"
check "root runs backup.sh every day at 01:30" 'crontab -l 2>/dev/null | grep -Eq "^30[[:space:]]+1[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+/root/site/scripts/backup.sh[[:space:]]*$"' \
  "(crontab -l; echo '30 1 * * * /root/site/scripts/backup.sh') | crontab -"
check "The existing disk-report job is still there" 'crontab -l 2>/dev/null | grep -q "disk-report" && crontab -l | grep -q backup.sh' \
  "Piping only your new line into crontab - replaces everything; include crontab -l"

section "9. Cron persistence"
F=/root/findings.txt
check "CRON_USER is right" '[ "$(_kv $F CRON_USER)" = intern ]' "crontab -l -u <user> for each account, or ls /var/spool/cron/crontabs"
check "CRON_TARGET is right" '[ "$(_kv $F CRON_TARGET)" = 203.0.113.50:4444 ]' "The address and port the job connects to, as IP:PORT"
check "The malicious line is gone" 'id intern && ! crontab -l -u intern 2>/dev/null | grep -q 203.0.113.50' "crontab -e -u intern, or rewrite it with grep -v"
check "intern's harmless job is kept" 'crontab -l -u intern 2>/dev/null | grep -q "\.tmp"' "Remove only the @reboot line"
