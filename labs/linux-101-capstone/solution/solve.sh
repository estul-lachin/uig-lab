# Reference solution for linux-101-capstone.
set -euo pipefail
S=/root/site

# 1-3. Layout, page, permissions
mkdir -p $S/{public,scripts,backups,logs}
echo "Welcome to Harbor Food Bank" > $S/public/index.html
chmod 750 $S/scripts

# 4. Hidden file
cp "$(find / -xdev -type f -name '*deploy*' -path '*harbor*' 2>/dev/null | head -n1)" $S/deploy.conf

# 5. Backup script
printf '#!/bin/bash\ntar czf /root/site/backups/site.tar.gz -C /root/site public\n' > $S/scripts/backup.sh
chmod +x $S/scripts/backup.sh
$S/scripts/backup.sh

# 6. User webadmin
groupadd -f webteam
id webadmin >/dev/null 2>&1 || useradd -m webadmin
usermod -aG webteam webadmin

# 7. IP address
hostname -I | awk '{print $1}' > $S/ip.txt

# 8. Cron job (keep the existing entries)
(crontab -l 2>/dev/null; echo '30 1 * * * /root/site/scripts/backup.sh') | crontab -

# 9. Cron persistence
{
  echo "CRON_USER=intern"
  echo "CRON_TARGET=$(crontab -l -u intern | grep -o '/dev/tcp/[^ ]*' | cut -d/ -f4,5 | tr / :)"
} > /root/findings.txt
crontab -l -u intern | grep -v '/dev/tcp/' | crontab -u intern -
