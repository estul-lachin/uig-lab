# Checks for ip-interfaces (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_by_ip() { ip -o -4 addr show | awk -v ip="$1" '$4 ~ "^"ip"/" {print $2}' | head -n1; }
_file() { tr -d "[:space:]" < "$1" 2>/dev/null; }
LAN=$(_by_ip 10.253.70.10)
MGMT=$(_by_ip 10.253.71.10)
A=/root/answers.txt

section "1. Default interface"
check "/root/iface.txt names the interface with the default route" '[ -n "$LAN" ] && [ "$(_file /root/iface.txt)" = "$LAN" ]' \
  "ip route show default (the word after dev), without any @ifN suffix"

section "2. IPv4 addresses"
check "/root/ipv4.txt lists both addresses, without prefix length" '[ -f /root/ipv4.txt ] && [ "$(sort /root/ipv4.txt | tr -d " ")" = "$(ip -4 -o addr show "$LAN" | awk "{print \$4}" | cut -d/ -f1 | sort)" ]' \
  "ip -4 -o addr show <iface>: one address per line, drop the /24"

section "3. MAC address"
check "/root/mac.txt holds the interface MAC" '[ -n "$LAN" ] && [ "$(_file /root/mac.txt)" = "$(cat /sys/class/net/$LAN/address)" ]' \
  "cat /sys/class/net/\$(cat /root/iface.txt)/address > /root/mac.txt"

section "4. Loopback"
check "lo is administratively up" 'ip -o link show lo | grep -q "[<,]UP[,>]"' "ip link set lo up"
check "127.0.0.1 answers" 'ping -c1 -W1 127.0.0.1' "lo must be up and still have 127.0.0.1"
check "/root/lo_state.txt holds lo's operstate" '[ -f /root/lo_state.txt ] && [ "$(_file /root/lo_state.txt)" = "$(cat /sys/class/net/lo/operstate)" ] && ip -o link show lo | grep -q "[<,]UP[,>]"' \
  "Read it after bringing lo up: cat /sys/class/net/lo/operstate"

section "5. Management interface"
check "MGMT_IFACE is right" '[ -n "$MGMT" ] && [ "$(_kv $A MGMT_IFACE)" = "$MGMT" ]' "The interface that has 10.253.71.10"
check "MGMT_MTU is right" '[ "$(_kv $A MGMT_MTU)" = 1400 ]' "ip link show <iface>: the number after mtu"
check "The management interface is up" '[ -n "$MGMT" ] && [ "$(cat /sys/class/net/$MGMT/operstate)" = up ]' "ip link set <iface> up"
check "10.253.71.1 is reachable through it" '[ -n "$MGMT" ] && ping -c1 -W2 -I "$MGMT" 10.253.71.1' \
  "Bringing it up restores its connected route"

section "6. The unexpected interface"
check "ROGUE_IFACE is right" '[ "$(_kv $A ROGUE_IFACE)" = upd0 ]' \
  "Compare every interface that has an IPv4 address with /root/asset-record.txt"
check "ROGUE_IP is right" '[ "$(_kv $A ROGUE_IP)" = 10.66.0.1 ]' "The address without the /24"
check "The interface is gone" '[ -f $A ] && [ ! -e /sys/class/net/upd0 ]' "ip link del <iface>"
check "The real interfaces are still there" '[ -n "$LAN" ] && [ -n "$MGMT" ]' "Delete only the unexpected one"
