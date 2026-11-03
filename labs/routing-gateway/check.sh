# Checks for routing-gateway (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_gw() { ip route show default | awk '{print $3}' | head -n1; }
_dev() { ip route get "$1" 2>/dev/null | grep -o "dev [^ ]*" | head -n1 | cut -d" " -f2; }
A=/root/answers.txt

section "1. The routing table"
check "/root/routes.txt holds the ip route output" '[ -f /root/routes.txt ] && grep -q "^default via" /root/routes.txt && grep -q "10.253.60.0/24" /root/routes.txt' \
  "ip route > /root/routes.txt"

section "2. Default gateway"
check "/root/gw.txt holds only the gateway address" '[ -n "$(_gw)" ] && [ "$(tr -d "[:space:]" < /root/gw.txt 2>/dev/null)" = "$(_gw)" ]' \
  "ip route show default | awk '{print \$3}' > /root/gw.txt"

section "3. Asking the kernel"
check "/root/nh.txt holds ip route get 1.1.1.1" '[ -f /root/nh.txt ] && grep -q "^1.1.1.1 via $(_gw) " /root/nh.txt' \
  "ip route get 1.1.1.1 > /root/nh.txt"
check "MGMT_DEV is the interface used for 10.253.61.20" 'v=$(_kv $A MGMT_DEV); [ -n "$v" ] && [ "$v" = "$(_dev 10.253.61.20)" ]' \
  "ip route get 10.253.61.20, then read the word after dev"
check "MGMT_VIA is none (directly connected)" '[ "$(_kv $A MGMT_VIA | tr A-Z a-z)" = none ]' \
  "No via in the answer means no gateway: the network is on the link"

section "4. Blackhole route"
check "203.0.113.0/24 is blackholed" 'ip route show type blackhole | grep -q "^blackhole 203.0.113.0/24"' \
  "ip route add blackhole 203.0.113.0/24"
check "The kernel now drops traffic to 203.0.113.9" '! ip route get 203.0.113.9 >/dev/null 2>&1 && ip route show type blackhole | grep -q 203.0.113.0/24' \
  "ip route get 203.0.113.9 should fail with 'No route to host' / invalid argument"

section "5. The diverted network"
check "ROGUE_PREFIX is right" '[ "$(_kv $A ROGUE_PREFIX)" = 198.51.100.0/24 ]' \
  "Which line in ip route has a via that isn't the default gateway?"
check "ROGUE_VIA is right" '[ "$(_kv $A ROGUE_VIA)" = 10.253.60.66 ]' "The address after via on that line"
check "The rogue route is gone" '[ -f $A ] && ! ip route show 198.51.100.0/24 | grep -q via' "ip route del 198.51.100.0/24"
check "198.51.100.7 now goes via the default gateway" '[ -n "$(_gw)" ] && ip route get 198.51.100.7 | grep -q "via $(_gw) "' \
  "ip route get 198.51.100.7"
check "The default route is still there" '[ -n "$(_gw)" ]' "Don't delete the default route"
