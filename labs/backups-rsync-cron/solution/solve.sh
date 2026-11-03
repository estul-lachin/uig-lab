# Reference solution for backups-rsync-cron.
set -euo pipefail

# 2. Key login (no passphrase: cron runs unattended)
mkdir -p /root/.ssh && chmod 700 /root/.ssh
[ -f /root/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -f /root/.ssh/id_ed25519
ap=$(mktemp)
printf '#!/bin/sh\necho vault-pass\n' > "$ap"; chmod 700 "$ap"
for _ in 1 2 3 4 5; do timeout 3 bash -c '</dev/tcp/backup/22' 2>/dev/null && break; sleep 1; done
SSH_ASKPASS=$ap SSH_ASKPASS_REQUIRE=force ssh-copy-id -o StrictHostKeyChecking=accept-new vault@backup >/dev/null 2>&1
rm -f "$ap"

# 3. backup.sh
cat > /usr/local/bin/backup.sh <<'S'
#!/bin/bash
set -euo pipefail
src=/srv/app/
opts=(--archive --delete --mkpath --exclude=cache/)
rsync "${opts[@]}" "$src" /srv/backup/app/
rsync "${opts[@]}" -e "ssh -o BatchMode=yes" "$src" "vault@backup:/backups/$(hostname)/app/"
printf '%s backup finished\n' "$(date --iso-8601=seconds)" >> /var/log/backup.log
S
script=/usr/local/bin/backup.sh
chmod 755 "$script"
"$script"

# 4. Schedule
echo '15 2 * * * root /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1' > /etc/cron.d/nightly-backup

# 5. Verify
(cd /srv/backup/app && find . -type f -printf '%P\n' | sort) > /root/backup_list.txt

# 6. Restore drill
rm /srv/app/config/app.conf
rsync --archive /srv/backup/app/config/app.conf /srv/app/config/app.conf
echo "RESTORE_TESTED=yes" > /root/answers.txt

# 7. The other cron job
echo "SUSPICIOUS_CRON=$(grep -rl '/tmp/' /etc/cron.d)" >> /root/answers.txt
rm -f /etc/cron.d/sysstat-extra /tmp/.sys/update.sh
