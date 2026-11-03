# Reference solution for sysctl-tuning.
set -euo pipefail
A=/root/answers.txt
H=/etc/sysctl.d/90-hardening.conf

# 1-2. Read and audit
sysctl vm.swappiness > /root/swap.txt
unsafe=""
for k in net.ipv4.ip_forward net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.send_redirects; do
  [ "$(sysctl -n "$k")" = 1 ] && unsafe="$unsafe,$k"
done

# 3. Runtime change (refused in a container)
printf 'sysctl -w vm.swappiness=10\nsysctl -w net.ipv4.ip_forward=0\n' > /root/tune.cmd
err=$(sysctl -w vm.swappiness=10 2>&1 >/dev/null | head -n1 || true)

# 4. Hardening drop-in
cat > "$H" <<'C'
# Hardening for edge-03
vm.swappiness = 10
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
C
sysctl -p "$H" > /root/reload.txt 2>&1 || true

# 5. Which file wins: the 99-* drop-in sorts after 90-hardening.conf
override=$(grep -l '^net.ipv4.ip_forward *= *1' /etc/sysctl.d/*.conf | sort | tail -n1)
rm -f -- "$override"

{
  echo "SWAPPINESS_PATH=/proc/sys/vm/swappiness"
  echo "IP_FORWARD_NOW=$(cat /proc/sys/net/ipv4/ip_forward)"
  echo "UNSAFE_NOW=${unsafe#,}"
  echo "RUNTIME_ERROR=$err"
  echo "EFFECTIVE_IP_FORWARD_BEFORE=1"
  echo "OVERRIDE_FILE=$override"
} > "$A"
