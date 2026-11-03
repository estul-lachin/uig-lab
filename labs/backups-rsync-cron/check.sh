# Checks for backups-rsync-cron (see templates/lab/check.sh for the rules).

B=/srv/backup/app
S=/usr/local/bin/backup.sh
_remote() { timeout 15 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 vault@backup "$@" 2>/dev/null; }
# Modes and owners of everything; size and mtime of files only (directory mtimes change with every edit).
_tree() { (cd "$1" && find . -path ./cache -prune -o \( -type f -printf "%p %m %u:%g %T@ %s\n" \) -o \( ! -type f -printf "%p %m %u:%g\n" \) | sort); }

section "1. Local mirror"
check "/srv/backup/app mirrors /srv/app (modes, owners, times)" '[ -d $B/config ] && [ "$(_tree /srv/app)" = "$(_tree $B)" ]' \
  "rsync -a /srv/app/ /srv/backup/app/ (the trailing slash on the source copies its contents)"
check "Not nested one level too deep" '[ -d $B ] && [ ! -e $B/app ]' "Without the trailing slash you get /srv/backup/app/app"
check "The cache is excluded" '[ -d $B/uploads ] && [ ! -e $B/cache ]' "--exclude cache/"
check "old-only.txt is gone" '[ -d $B/uploads ] && [ ! -e $B/old-only.txt ]' "--delete removes what no longer exists in the source"

section "2. Key login to the backup server"
check "root can log in to vault@backup without a password or passphrase" '_remote true' \
  "ssh-keygen with an empty passphrase (cron can't type one), then ssh-copy-id vault@backup (password vault-pass)"

section "3. backup.sh"
check "backup.sh is executable with a shebang and set -euo pipefail" '[ -x $S ] && head -n1 $S | grep -q "^#!" && grep -q "set -euo pipefail" $S' "chmod +x"
check "Running it picks up a new file, locally and on the server" '[ -x $S ] && date +%s%N > /srv/app/uploads/probe.txt && $S >/dev/null 2>&1 && cmp -s /srv/app/uploads/probe.txt $B/uploads/probe.txt && [ "$(_remote cat /backups/web-01/app/uploads/probe.txt)" = "$(cat /srv/app/uploads/probe.txt)" ]' \
  "Mirror to $B and to vault@backup:/backups/web-01/app/"
check "The remote copy keeps config private" '[ "$(_remote stat -c %a /backups/web-01/app/config/app.conf)" = 640 ] && [ -z "$(_remote ls /backups/web-01/app/cache 2>/dev/null)" ]' \
  "-a keeps modes; exclude the cache there too"
check "It also deletes on the server" '[ -x $S ] && rm -f /srv/app/uploads/probe.txt && $S >/dev/null 2>&1 && ! _remote test -e /backups/web-01/app/uploads/probe.txt' "--delete on the remote run too"
check "It appends a line with a timestamp to /var/log/backup.log" '[ -x $S ] && n=$(wc -l < /var/log/backup.log 2>/dev/null || echo 0) && $S >/dev/null 2>&1 && [ "$(wc -l < /var/log/backup.log)" -gt "$n" ] && tail -n1 /var/log/backup.log | grep -q "20[0-9][0-9]-"' \
  "echo \"\$(date -Is) backup ok\" >> /var/log/backup.log"
rm -f /srv/app/uploads/probe.txt

section "4. Schedule"
_cronlines() { { crontab -l 2>/dev/null | sed "s/^/U /"; cat /etc/cron.d/* 2>/dev/null | sed "s/^/D /"; } | grep -v "^. *#"; }
check "backup.sh runs every day at 02:15 as root" '_cronlines | grep -Eq "^(U 15[[:space:]]+2[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+|D 15[[:space:]]+2[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+root[[:space:]]+)/usr/local/bin/backup.sh"' \
  "/etc/cron.d/nightly-backup: 15 2 * * * root /usr/local/bin/backup.sh (or root's crontab, without the user field)"

section "5. Verify"
check "/root/backup_list.txt lists every file in the local backup" '[ -f /root/backup_list.txt ] && [ "$(sort /root/backup_list.txt | grep .)" = "$(cd $B && find . -type f | sed "s|^\./||" | sort)" ]' \
  "Relative paths, files only, one per line"

section "6. Restore"
check "config/app.conf is back, with content, mode 640 and owner app" '[ "$(stat -c %a:%U:%G /srv/app/config/app.conf 2>/dev/null)" = 640:app:app ] && grep -q "db_password=lab-only" /srv/app/config/app.conf' \
  "Delete it from /srv/app, then restore it from $B with rsync -a (or cp -a)"
check "RESTORE_TESTED=yes in /root/answers.txt" 'grep -qx "RESTORE_TESTED=yes" /root/answers.txt 2>/dev/null' "Write it once you've actually deleted and restored the file"

section "7. The other cron job"
check "SUSPICIOUS_CRON names the file" 'grep -qx "SUSPICIOUS_CRON=/etc/cron.d/sysstat-extra" /root/answers.txt 2>/dev/null' "grep -r /tmp /etc/cron* /var/spool/cron"
check "It and its script are gone" '[ -f /root/answers.txt ] && [ ! -e /etc/cron.d/sysstat-extra ] && [ ! -e /tmp/.sys/update.sh ]' "Remove the cron file and the script it runs"
