# Checks for ad-dns (see templates/lab/check.sh for the rules).
# Runs on DC01 and asks its DNS server; log answers are computed from the log itself.
# The first start plants a record with a temporary DC (dc/plant.sh): wait for it to finish.

A=/root/answers.txt
LOG=/var/log/dns/queries.log
NET=10.203.17
_kv() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
_n() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-' | sed 's/\.$//'; }
_any() { _v=$(_kv "$1"); shift; [ -n "$_v" ] || return 1; for _e in "$@"; do [ "$(_n "$_v")" = "$(_n "$_e")" ] && return 0; done; return 1; }
# dig prints connection errors on stdout as ";;" lines: drop them, an unreachable server answers nothing.
# A single UDP query can be dropped under load (CI), so retry a few times (+tries only retries on
# no answer, never on NXDOMAIN) - this keeps the one-shot A-record checks from flaking.
_dig() { dig +short +time=2 +tries=3 @127.0.0.1 "$@" 2>/dev/null | grep -v '^;'; }
_rogue() { awk -v ip=$NET.66 '$4 == "wpad.ridgeline.local" && $6 == ip' $LOG; }

for _ in $(seq 1 45); do [ -e /var/lib/samba/.lab-planted ] && [ -n "$(_dig dc01.ridgeline.local)" ] && break; sleep 2; done

section "0. The DNS server"
check "DC01 answers DNS queries for ridgeline.local" '[ "$(_dig dc01.ridgeline.local)" = $NET.10 ]' \
  "Samba needs a few seconds after ./lab up; run the check again"

section "1. AD-integrated DNS (the core questions)"
check "DNS_CONSOLE: the .msc that opens DNS Manager" '_any DNS_CONSOLE dnsmgmt.msc' "dns + mgmt"
check "ZONE_STORAGE: how the zone is stored so it replicates with the directory" '_any ZONE_STORAGE "Active Directory-integrated" "AD-integrated" "Active Directory integrated" "AD integrated" "ADintegrated"' \
  "Not a zone file: the records are directory objects"
check "NAME_TO_IP: the record type that maps a name to an IPv4 address" '_any NAME_TO_IP A' "AAAA is IPv6"
check "DC_IP: the address dc01.ridgeline.local resolves to" '_any DC_IP "$(_dig dc01.ridgeline.local)"' "dig or nslookup against 127.0.0.1"
check "DC_LOCATOR: the SRV name clients query to find a DC (LDAP)" '_any DC_LOCATOR _ldap._tcp.ridgeline.local' "_service._protocol.domain"
check "RESOLVE_CMDLET: the PowerShell cmdlet that resolves DNS names" '_any RESOLVE_CMDLET Resolve-DnsName' "Verb-Noun: resolve a DNS name"
check "DNS_PORT: the port DNS uses" '_any DNS_PORT 53' "UDP, and TCP for big answers and zone transfers"

section "2. Inside the zone"
check "ZONE_PARTITION: the application partition the zone is stored in" '_any ZONE_PARTITION DomainDnsZones "DC=DomainDnsZones"' \
  "Search the directory for objectClass=dnsZone and read the DN"
check "MSDCS_PARTITION: the partition that holds the forest-wide _msdcs zone" '_any MSDCS_PARTITION ForestDnsZones "DC=ForestDnsZones"' \
  "The same search; one zone is stored for the whole forest"
check "KERBEROS_PORT: the port in the _kerberos._tcp SRV record" '_any KERBEROS_PORT "$(_dig SRV _kerberos._tcp.ridgeline.local | head -n1 | cut -d" " -f3)"' \
  "An SRV answer is priority, weight, port, target"
check "INTRANET_TARGET: the host intranet.ridgeline.local is an alias for" '_any INTRANET_TARGET rdg-fs01.ridgeline.local rdg-fs01' "Record type CNAME"

section "3. The reverse zone"
check "The reverse zone for $NET.0/24 exists" '_dig SOA 17.203.10.in-addr.arpa | grep -q .' "samba-tool dns zonecreate; reverse zones are named backwards"
check "$NET.10 resolves back to dc01.ridgeline.local" '[ "$(_dig -x $NET.10)" = dc01.ridgeline.local. ]' "A PTR record named 10 in that zone, with the full name and its final dot"
check "$NET.21 resolves back to rdg-fs01.ridgeline.local" '[ "$(_dig -x $NET.21)" = rdg-fs01.ridgeline.local. ]' "The same for the file server"

section "4. The planted record"
check "ROGUE_NAME: the record that should not exist" '_any ROGUE_NAME wpad wpad.ridgeline.local' "Browsers look up this name to find a proxy configuration"
check "ROGUE_IP: where it points" '_any ROGUE_IP $NET.66' "No server has that address"
check "ROGUE_OWNER: the account that created it" '_any ROGUE_OWNER bnakamura "RIDGELINE\\bnakamura"' \
  "Every DNS record is a directory object with an owner: samba-tool dsacl get, then turn the SID into a name"
check "WPAD_FIRST: when a client first got the rogue answer (HH:MM:SS)" '_any WPAD_FIRST "$(_rogue | head -n1 | cut -c12-19)"' "The log is in time order"
check "WPAD_CLIENTS: how many different clients got it" '_any WPAD_CLIENTS "$(_rogue | awk "{print \$2}" | sort -u | wc -l | tr -d " ")"' "awk, sort -u, wc -l"
check "The wpad record is gone, the rest of the zone is not" '[ "$(_dig dc01.ridgeline.local)" = $NET.10 ] && [ "$(_dig rdg-fs01.ridgeline.local)" = $NET.21 ] && [ -z "$(_dig wpad.ridgeline.local)" ]' \
  "samba-tool dns delete needs the record data too"

section "5. DNS tunneling in the log"
check "TUNNEL_CLIENT: the client that tunnels data out over DNS" '_any TUNNEL_CLIENT $NET.57' "Long, random-looking labels, many of them, one destination"
check "TUNNEL_HOST: its host name" '_any TUNNEL_HOST ws-0107 ws-0107.ridgeline.local' "Which A record has that address?"
check "TUNNEL_DOMAIN: the domain it sends to" '_any TUNNEL_DOMAIN sync-telemetry.example' "Strip the chunks, keep the registered domain"
check "TUNNEL_QTYPE: the record type it asks for" '_any TUNNEL_QTYPE TXT' "Column 3"
