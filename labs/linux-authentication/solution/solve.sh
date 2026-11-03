# Reference solution for linux-authentication.
set -euo pipefail

# 1. Reading passwd and shadow
hash=$(getent shadow nadia | cut -d: -f2)
case $hash in '$6$'*) alg=sha512 ;; '$y$'*) alg=yescrypt ;; '$5$'*) alg=sha256 ;; '$1$'*) alg=md5 ;; *) alg=unknown ;; esac
locked=$(awk -F: '$2 ~ /^!\$/ {print $1}' /etc/shadow | grep -vx tomas | grep -vx legacy | head -n1)
{
  echo "NADIA_UID=$(getent passwd nadia | cut -d: -f3)"
  echo "NADIA_SHELL=$(getent passwd nadia | cut -d: -f7)"
  echo "NADIA_HASH=$alg"
  echo "LOCKED_USER=$locked"
} > /root/answers.txt

# 2. Changing accounts
usermod -c "Lena Fischer" -s /bin/bash lena
usermod -aG backup lena
usermod -L tomas
usermod -e 2026-12-31 intern

# 3. SSH key login to server
mkdir -p /root/.ssh && chmod 700 /root/.ssh
[ -f /root/.ssh/id_rsa ] || ssh-keygen -q -t rsa -b 4096 -C backup-key -N BackupKey2026 -f /root/.ssh/id_rsa
ap=$(mktemp)
cat > "$ap" <<'ASK'
#!/bin/sh
case "$1" in *assphrase*) echo BackupKey2026 ;; *) echo ops-pass ;; esac
ASK
chmod 700 "$ap"
for _ in 1 2 3 4 5; do timeout 5 bash -c '</dev/tcp/server/22' 2>/dev/null && break; sleep 1; done
SSH_ASKPASS=$ap SSH_ASKPASS_REQUIRE=force \
  ssh-copy-id -o StrictHostKeyChecking=accept-new -i /root/.ssh/id_rsa.pub ops@server >/dev/null 2>&1
rm -f "$ap"

# 4. Hunting backdoors
{
  echo "UID0_ACCOUNT=$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd)"
  echo "MD5_ACCOUNT=$(awk -F: '$2 ~ /^\$1\$/ {print $1}' /etc/shadow)"
  echo "ODD_HOME_ACCOUNT=$(awk -F: '$7 !~ /(nologin|false)$/ && $6 !~ /^\/(home|root)/ && $1 != "sync" {print $1}' /etc/passwd)"
  echo "ROGUE_KEY_COMMENT=$(grep -v ' lena@laptop$' /home/lena/.ssh/authorized_keys | awk '{print $NF}')"
} > /root/findings.txt
userdel -f sysupdate 2>/dev/null || true
usermod -L legacy
usermod -s /usr/sbin/nologin svc-cache
ak=/home/lena/.ssh/authorized_keys
grep -v 'deploy@build-07' "$ak" > "$ak.new"; cat "$ak.new" > "$ak"; rm -f "$ak.new"
chmod 700 /home/lena/.ssh
chmod 600 "$ak"
chown -R lena:lena /home/lena/.ssh
