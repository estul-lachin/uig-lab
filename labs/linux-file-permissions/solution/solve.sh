# Reference solution for linux-file-permissions.
set -euo pipefail
P=/srv/print/price-list.txt

# 1. Create and inspect
touch "$P"
echo "INITIAL_PERMS=$(stat -c %A "$P")" > /root/answers.txt

# 2. Octal mode
chmod 740 "$P"

# 3. Symbolic mode
chmod u-x,g=rw,o+r /srv/print/order-form.txt

# 4. Ownership
chown pia "$P"
chgrp printers "$P"
chown -R pia:printers /srv/print/archive

# 5. Special bits
{
  echo "PASSWD_SPECIAL=suid"
  echo "TMP_SPECIAL=sticky"
  echo "SGID_FILE=$(find /usr/bin -perm /2000 -type f | head -n1)"
} >> /root/answers.txt

# 6. Permission audit
{
  echo "SUID_BACKDOOR=$(find /var/tmp -perm /4000 -type f | head -n1)"
  echo "WORLD_WRITABLE=$(find /etc /root -perm /002 -type f 2>/dev/null | head -n1)"
  echo "BAD_OWNER=$(find /usr/local/bin -type f ! -user root | head -n1)"
  echo "NO_STICKY=$(find / -xdev -maxdepth 2 -type d -perm -0002 ! -perm /1000 2>/dev/null | head -n1)"
} > /root/findings.txt
rm -f /var/tmp/.helper
chmod 644 /etc/cron.d/cleanup
chown root:root /usr/local/bin/print-backup
chmod 1777 /tmp
