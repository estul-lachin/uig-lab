# Checks for dns-resolution (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_ip() { getent hosts "$1" | awk '{print $1}' | head -n1; }

section "1. Configured nameservers"
check "/root/ns.txt lists the nameserver IPs, one per line" '[ -s /root/ns.txt ] && [ "$(cat /root/ns.txt)" = "$(grep ^nameserver /etc/resolv.conf | awk "{print \$2}")" ]' \
  "grep ^nameserver /etc/resolv.conf | awk '{print \$2}' > /root/ns.txt"

section "2. Lookups with dig"
check "/root/a_portal.txt holds both A records" '[ -f /root/a_portal.txt ] && [ "$(sort /root/a_portal.txt | tr -d " ")" = "$(printf "10.20.0.10\n10.20.0.11")" ]' \
  "dig +short portal.corp.lab A > /root/a_portal.txt (one name, two addresses)"
check "/root/ptr.txt holds the name for 10.20.0.15" '[ "$(tr -d "[:space:]" < /root/ptr.txt 2>/dev/null | sed "s/\.$//")" = files.corp.lab ]' \
  "dig +short -x 10.20.0.15"

section "3. Local override"
check "test.corp.lab resolves to 10.99.99.99" '[ "$(_ip test.corp.lab)" = 10.99.99.99 ]' \
  "echo '10.99.99.99 test.corp.lab' | sudo tee -a /etc/hosts"
check "localhost is still in /etc/hosts" 'grep -Eq "^127\.0\.0\.1[[:space:]]+.*localhost" /etc/hosts' \
  "tee without -a overwrites the whole file"

section "4. Resolver order"
check "/root/nss_hosts.txt holds the hosts: line" '[ -f /root/nss_hosts.txt ] && [ "$(cat /root/nss_hosts.txt)" = "$(grep ^hosts /etc/nsswitch.conf)" ]' \
  "grep ^hosts /etc/nsswitch.conf > /root/nss_hosts.txt"

section "5. Hosts-file hijack"
F=/root/findings.txt
check "HIJACKED_NAME is right" '[ "$(_kv $F HIJACKED_NAME)" = updates.corp.lab ]' \
  "Compare each name in /etc/hosts with what dig says"
check "ROGUE_IP is right" '[ "$(_kv $F ROGUE_IP)" = 203.0.113.66 ]' "The address /etc/hosts gives it"
check "REAL_IP is right" '[ "$(_kv $F REAL_IP)" = 10.20.0.30 ]' "dig +short updates.corp.lab"
check "updates.corp.lab resolves to its DNS address again" '[ -f $F ] && [ "$(_ip updates.corp.lab)" = 10.20.0.30 ]' \
  "Remove the line from /etc/hosts. sed -i fails on this bind-mounted file; write the filtered copy back with cat"
check "Your test.corp.lab override is still there" '[ "$(_ip test.corp.lab)" = 10.99.99.99 ]' "Only delete the rogue line"
