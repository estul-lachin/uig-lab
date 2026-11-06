# Reference solution for ad-dns: answers from the DNS server, the directory and the log, then the fixes.
set -eu
umask 022
U='Administrator%Lab-AD-2026!'
LOG=/var/log/dns/queries.log
SAM=/var/lib/samba/private/sam.ldb
q() { dig +short @127.0.0.1 "$@" | grep -v '^;' || true; }
for _ in $(seq 1 45); do [ -e /var/lib/samba/.lab-planted ] && [ -n "$(q dc01.ridgeline.local 2>/dev/null)" ] && break; sleep 2; done

zones=$(ldbsearch --cross-ncs -H $SAM '(objectClass=dnsZone)' dn | sed -n 's/^dn: //p')
part() { echo "$zones" | grep "^DC=$1," | sed 's/.*,DC=\([A-Za-z]*DnsZones\),.*/\1/'; }
node="DC=wpad,DC=ridgeline.local,CN=MicrosoftDNS,DC=DomainDnsZones,DC=ridgeline,DC=local"
owner_sid=$(samba-tool dsacl get --objectdn="$node" -H $SAM | sed -n 's/.*O:\(S-[0-9-]*\)G:.*/\1/p')
owner=$(ldbsearch -H $SAM "(objectSid=$owner_sid)" sAMAccountName | sed -n 's/^sAMAccountName: //p')
rogue=$(awk '$4 == "wpad.ridgeline.local" && $6 == "10.203.17.66"' $LOG)
tunnel=$(awk '$3 == "TXT" {print $2, $4}' $LOG | awk '{n=split($2, p, "."); print $1, p[n-1] "." p[n]}' | sort | uniq -c | sort -rn | head -n1)
tclient=$(echo "$tunnel" | awk '{print $2}')
thost=$(samba-tool dns query 127.0.0.1 ridgeline.local @ A -U "$U" | awk -v ip="$tclient" '/Name=/ {sub(/.*Name=/, ""); sub(/,.*/, ""); n=$0} $0 ~ "A: " ip " " {print n}')
{
  echo "DNS_CONSOLE=dnsmgmt.msc"
  echo "ZONE_STORAGE=Active Directory-integrated"
  echo "NAME_TO_IP=A"
  echo "DC_IP=$(q dc01.ridgeline.local)"
  echo "DC_LOCATOR=_ldap._tcp.ridgeline.local"
  echo "RESOLVE_CMDLET=Resolve-DnsName"
  echo "DNS_PORT=53"
  echo "ZONE_PARTITION=$(part ridgeline.local)"
  echo "MSDCS_PARTITION=$(part _msdcs.ridgeline.local)"
  echo "KERBEROS_PORT=$(q SRV _kerberos._tcp.ridgeline.local | head -n1 | cut -d' ' -f3)"
  echo "INTRANET_TARGET=$(q CNAME intranet.ridgeline.local)"
  echo "ROGUE_NAME=wpad"
  echo "ROGUE_IP=$(q wpad.ridgeline.local)"
  echo "ROGUE_OWNER=$owner"
  echo "WPAD_FIRST=$(echo "$rogue" | head -n1 | cut -c12-19)"
  echo "WPAD_CLIENTS=$(echo "$rogue" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')"
  echo "TUNNEL_CLIENT=$tclient"
  echo "TUNNEL_HOST=$thost"
  echo "TUNNEL_DOMAIN=$(echo "$tunnel" | awk '{print $3}')"
  echo "TUNNEL_QTYPE=TXT"
} > /root/answers.txt

samba-tool dns zonecreate 127.0.0.1 17.203.10.in-addr.arpa -U "$U" >/dev/null
samba-tool dns add 127.0.0.1 17.203.10.in-addr.arpa 10 PTR dc01.ridgeline.local -U "$U" >/dev/null
samba-tool dns add 127.0.0.1 17.203.10.in-addr.arpa 21 PTR rdg-fs01.ridgeline.local -U "$U" >/dev/null
samba-tool dns delete 127.0.0.1 ridgeline.local wpad A 10.203.17.66 -U "$U" >/dev/null
