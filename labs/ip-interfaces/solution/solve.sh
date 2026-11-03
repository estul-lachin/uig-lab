# Reference solution for ip-interfaces.
set -euo pipefail
cd /root

# 1-3. Default interface, its addresses and MAC
ip route show default | awk '{print $5}' | cut -d@ -f1 > iface.txt
ip -4 -o addr show "$(cat iface.txt)" | awk '{print $4}' | cut -d/ -f1 > ipv4.txt
cat "/sys/class/net/$(cat iface.txt)/address" > mac.txt

# 4. Loopback
ip link set lo up
cat /sys/class/net/lo/operstate > lo_state.txt

# 5. Management interface (has 10.253.71.10, currently down)
mgmt=$(ip -o -4 addr show | awk '$4 ~ /^10\.253\.71\.10\// {print $2}')
mtu=$(cat "/sys/class/net/$mgmt/mtu")
ip link set "$mgmt" up

# 6. The unexpected interface: has an address but isn't in the asset record
rogue=""
for i in $(ip -o -4 addr show | awk '{print $2}' | sort -u); do
  grep -q "^$i " asset-record.txt || rogue=$i
done
rip=$(ip -4 -o addr show "$rogue" | awk '{print $4}' | cut -d/ -f1 | head -n1)
{
  echo "MGMT_IFACE=$mgmt"
  echo "MGMT_MTU=$mtu"
  echo "ROGUE_IFACE=$rogue"
  echo "ROGUE_IP=$rip"
} > answers.txt
ip link del "$rogue"
sleep 1
