# Reference solution for systemd-services.
set -euo pipefail
timeout 30 systemctl is-system-running --wait >/dev/null 2>&1 || true

# 1. The program
cat > /usr/local/bin/heartbeat.sh <<'S'
#!/bin/bash
interval=${INTERVAL:-5}
while :; do
  printf 'heartbeat from %s\n' "$(hostname)"
  sleep "$interval"
done
S
chmod 755 /usr/local/bin/heartbeat.sh

# 2-3. Unit with its own user, enabled and started
id heartbeat >/dev/null 2>&1 || useradd --system --shell /usr/sbin/nologin heartbeat
printf '%s\n' '[Unit]' 'Description=Heartbeat demo service' 'After=network.target' '' '[Service]' \
  'ExecStart=/usr/local/bin/heartbeat.sh' 'User=heartbeat' 'Restart=on-failure' 'RestartSec=1' '' \
  '[Install]' 'WantedBy=multi-user.target' > /etc/systemd/system/heartbeat.service

# 5. Drop-in (what systemctl edit would write)
mkdir -p /etc/systemd/system/heartbeat.service.d
printf '[Service]\nEnvironment=INTERVAL=2\n' > /etc/systemd/system/heartbeat.service.d/override.conf
systemctl --no-ask-password daemon-reload
systemctl enable --now heartbeat.service >/dev/null 2>&1
systemctl restart heartbeat.service
systemctl cat heartbeat.service > /root/unit.txt

# 6. The failing unit
reason=$(sed -n 's/^ExecStart=//p' /etc/systemd/system/report.service)
sed 's|^ExecStart=.*|ExecStart=/usr/local/bin/report.sh|' /etc/systemd/system/report.service > /tmp/report.service
cat /tmp/report.service > /etc/systemd/system/report.service && rm /tmp/report.service
systemctl --no-ask-password daemon-reload
systemctl restart report.service

# 7. The backdoor: an enabled service that no package installed
bd=""
for f in /etc/systemd/system/*.service; do
  [ -L "$f" ] && continue   # masked units are symlinks to /dev/null
  n=$(basename "$f")
  case $n in heartbeat.service|report.service) continue ;; esac
  dpkg -S "$f" >/dev/null 2>&1 || bd=$n
done
target=$(grep -o '/dev/tcp/[^;]*' "/etc/systemd/system/$bd" | cut -d/ -f4,5 | tr / :)
systemctl disable --now "$bd" >/dev/null 2>&1
rm -f "/etc/systemd/system/$bd"
systemctl --no-ask-password daemon-reload
systemctl reset-failed >/dev/null 2>&1 || true

{
  echo "FAILED_REASON=$reason"
  echo "BACKDOOR_UNIT=$bd"
  echo "BACKDOOR_TARGET=$target"
} > /root/answers.txt
sleep 3
