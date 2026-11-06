# Reference solution for ad-core-concepts: answers read from the live DC, then the two changes.
set -eu
umask 022
SAM=/var/lib/samba/private/sam.ldb
root() { ldapsearch -x -LLL -H ldap://localhost -s base -b "" "$1" | sed -n "s/^$1: //p"; }
for _ in $(seq 1 30); do [ -n "$(root dnsHostName 2>/dev/null)" ] && break; sleep 2; done

info=$(samba-tool domain info 127.0.0.1)
field() { echo "$info" | sed -n "s/^$1 *: //p"; }
schema=$(root schemaNamingContext)
bind=$(ldapsearch -x -H ldap://localhost -D Administrator@ridgeline.local -w 'Lab-AD-2026!' -s base -b "" 2>&1 | sed -n 's/.*(\([0-9]*\)).*/\1/p' | head -n1)
srv=$(dig +short @127.0.0.1 SRV _gc._tcp.ridgeline.local)
{
  echo "FOREST=$(field Forest)"
  echo "BOUNDARY=forest"
  echo "NETBIOS=$(field 'Netbios domain')"
  echo "OU_TERM=OU"
  echo "FUNCTIONAL_LEVEL=$(samba-tool domain level show | sed -n 's/^Domain function level: (Windows) //p')"
  echo "LEVEL_NUMBER=$(root domainFunctionality)"
  echo "SCHEMA=schema"
  echo "SCHEMA_VERSION=$(ldbsearch -H $SAM -s base -b "$schema" objectVersion | sed -n 's/^objectVersion: //p')"
  echo "GC_PORT=$(echo "$srv" | cut -d' ' -f3)"
  echo "GC_TLS_PORT=3269"
  echo "GC_SRV=_gc._tcp.ridgeline.local"
  echo "BIND_RESULT=$bind"
  echo "FSMO_COUNT=5"
  echo "FSMO_HOLDER=$(field 'DC netbios name')"
  echo "FSMO_LISTED=$(samba-tool fsmo show | grep -c owner:)"
  echo "TIME_ROLE=PDC Emulator"
  echo "MISPLACED=$(ldbsearch -H $SAM -s one -b CN=Computers,DC=ridgeline,DC=local '(objectClass=computer)' sAMAccountName | sed -n 's/^sAMAccountName: //p' | tr -d '$')"
} > /root/answers.txt

samba-tool ou add OU=Contractors,OU=Ridgeline >/dev/null
samba-tool computer move WS-TEMP07 OU=Workstations,OU=Ridgeline >/dev/null
