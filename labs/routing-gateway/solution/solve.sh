# Reference solution for routing-gateway.
set -euo pipefail

# 1. The routing table
ip route > /root/routes.txt

# 2. Default gateway
ip route show default | awk '{print $3}' > /root/gw.txt

# 3. Asking the kernel
ip route get 1.1.1.1 > /root/nh.txt
dev=$(ip route get 10.253.61.20 | grep -o 'dev [^ ]*' | awk '{print $2}')
via=$(ip route get 10.253.61.20 | grep -o 'via [^ ]*' | awk '{print $2}' || true)

# 4. Blackhole route
ip route add blackhole 203.0.113.0/24

# 5. The diverted network
gw=$(cat /root/gw.txt)
rogue=$(ip route | awk -v gw="$gw" '$2 == "via" && $3 != gw && $1 != "default" {print $1, $3}' | head -n1)
{
  echo "MGMT_DEV=$dev"
  echo "MGMT_VIA=${via:-none}"
  echo "ROGUE_PREFIX=${rogue% *}"
  echo "ROGUE_VIA=${rogue#* }"
} > /root/answers.txt
ip route del "${rogue% *}"
