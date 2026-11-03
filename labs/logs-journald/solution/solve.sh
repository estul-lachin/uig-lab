# Reference solution for logs-journald.
set -euo pipefail
J="journalctl --no-pager"

# 1-2. Boots, and the incident boot's kernel messages
$J --list-boots > /root/boots.txt
boot=$($J --list-boots | awk '$0 ~ /2026-10-30/ {print $2}' | head -n1)
$J -b "$boot" -k > /root/boot.log
killed=$($J -b "$boot" -k -g 'Out of memory' -q | sed -n 's/.*Killed process [0-9]* (\([^)]*\)).*/\1/p' | head -n1)

# 3. ssh.service in the attack window
$J -u ssh.service --since "2026-10-30 02:14:00" --until "2026-10-30 02:16:00" > /root/unit.log
win=$(grep -v '^-- ' /root/unit.log)
ip=$(echo "$win" | grep -o 'Failed password for .* from [0-9.]*' | awk '{print $NF}' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
failed=$(echo "$win" | grep -c 'Failed password')
accepted=$(echo "$win" | grep "Accepted .* from $ip " | head -n1)

# 4. Priority and grep
errs=$($J -p err -q | wc -l)
cmd=$($J -g 'COMMAND=' -q | sed -n 's/.*COMMAND=//p' | head -n1)

# 5. Rotated plain-text logs
authfail=$(zgrep -h 'Failed password' /var/log/auth.log* | wc -l)
oldest=$(ls /var/log/auth.log* | sort -V | tail -n1)
oldip=$(zgrep -ho 'from [0-9.]*' "$oldest" | awk '{print $2}' | sort -u | head -n1)

{
  echo "INCIDENT_BOOT=$boot"
  echo "KILLED_PROCESS=$killed"
  echo "ATTACKER_IP=$ip"
  echo "FAILED_COUNT=$failed"
  echo "BREACHED_USER=$(echo "$accepted" | awk '{for (i=1;i<=NF;i++) if ($i=="for") print $(i+1)}')"
  echo "LOGIN_TIME=$(echo "$accepted" | awk '{print $3}')"
  echo "ERR_ENTRIES=$errs"
  echo "ROOT_COMMAND=$cmd"
  echo "AUTH_FAILED_ALL=$authfail"
  echo "AUTH_OLDEST_ATTACKER=$oldip"
} > /root/answers.txt

# 6. logrotate config
cat > /etc/logrotate.d/orders <<'C'
/var/log/orders/*.log {
    weekly
    rotate 4
    compress
    copytruncate
    missingok
    notifempty
}
C

# 7. Dry run (logrotate -d reports on stderr)
logrotate -d /etc/logrotate.d/orders > /root/lr.log 2>&1
