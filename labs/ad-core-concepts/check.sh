# Checks for ad-core-concepts (see templates/lab/check.sh for the rules).
# Runs on DC01 itself; values that depend on the Samba build are read from the directory.

A=/root/answers.txt
DOM=DC=ridgeline,DC=local
SAM=/var/lib/samba/private/sam.ldb
_kv() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
_n() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-' | sed 's/\.$//'; }
_is() { _v=$(_kv "$1"); [ -n "$_v" ] && [ "$(_n "$_v")" = "$(_n "$2")" ]; }
_any() { _k=$1; shift; for _e in "$@"; do _is "$_k" "$_e" && return 0; done; return 1; }
_root() { ldapsearch -x -LLL -H ldap://localhost -s base -b "" "$1" 2>/dev/null | sed -n "s/^$1: //p"; }
_dn() { [ "$(ldbsearch -H $SAM -s base -b "$1" dn 2>/dev/null | grep -c '^dn:')" = 1 ]; }

for _ in $(seq 1 30); do [ -n "$(_root dnsHostName)" ] && break; sleep 2; done

section "0. The domain controller"
check "DC01 answers LDAP queries" '[ "$(_root dnsHostName)" = dc01.ridgeline.local ]' \
  "Samba needs a few seconds after ./lab up; run the check again"

section "1. The hierarchy"
check "FOREST: the name of the forest" '_is FOREST ridgeline.local' "samba-tool domain info, or rootDomainNamingContext in the rootDSE"
check "BOUNDARY: the level that is the real security boundary" '_is BOUNDARY forest' "Not the domain: every domain in it trusts the others"
check "NETBIOS: the domain s short (NetBIOS) name" '_is NETBIOS RIDGELINE' "The part before the backslash in DOMAIN\\user"
check "OU_TERM: the container for organising objects and linking Group Policy" '_any OU_TERM OU' "Abbreviation of organizational unit"

section "2. Functional level"
check "FUNCTIONAL_LEVEL: the Windows Server level the domain runs at" '[ "$(_kv FUNCTIONAL_LEVEL | tr -dc 0-9)" = 2016 ]' "samba-tool domain level show"
check "LEVEL_NUMBER: how the rootDSE writes that level" '_is LEVEL_NUMBER "$(_root domainFunctionality)"' "ldapsearch -x -s base -b \"\" asks the rootDSE without logging in"

section "3. The schema"
check "SCHEMA: the forest-wide blueprint of classes and attributes" '_is SCHEMA schema' "It has its own naming context"
check "SCHEMA_VERSION: the schema s objectVersion" '_is SCHEMA_VERSION "$(ldbsearch -H $SAM -s base -b CN=Schema,CN=Configuration,$DOM objectVersion 2>/dev/null | sed -n "s/^objectVersion: //p")"' \
  "schemaNamingContext in the rootDSE gives its DN; ldbsearch reads the local database"

section "4. Global Catalog and LDAP"
check "GC_PORT: the Global Catalog s TCP port" '_is GC_PORT 3268' "Plain LDAP is 389"
check "GC_TLS_PORT: the same over TLS" '_is GC_TLS_PORT 3269' "LDAPS is 636"
check "GC_SRV: the DNS name clients query to find a Global Catalog" '_is GC_SRV _gc._tcp.ridgeline.local' \
  "An SRV record; dig @127.0.0.1 SRV <name> returns the host and the port"
check "BIND_RESULT: the LDAP result code of a password bind over plain LDAP" '_is BIND_RESULT 8' \
  "ldapsearch -x -D Administrator@ridgeline.local -W on ldap://dc01, then the same on ldaps://dc01"

section "5. FSMO roles"
check "FSMO_COUNT: how many FSMO roles AD defines" '_is FSMO_COUNT 5' "Two forest-wide, three per domain"
check "FSMO_HOLDER: the DC that holds them all here" '_any FSMO_HOLDER DC01 dc01.ridgeline.local' "samba-tool fsmo show (netdom query fsmo on Windows)"
check "FSMO_LISTED: how many roles samba-tool fsmo show lists" '_is FSMO_LISTED "$(samba-tool fsmo show 2>/dev/null | grep -c "owner:")"' \
  "The extra ones belong to the DNS application partitions"
check "TIME_ROLE: the role that is the domain s time source and gets password changes first" '_any TIME_ROLE "PDC Emulator" PdcEmulationMaster PDC' \
  "One of the three domain-wide roles"

section "6. Organising objects"
check "MISPLACED: the computer that is in no OU" '_any MISPLACED WS-TEMP07 "WS-TEMP07\$"' \
  "New computers land in a container, not an OU; list what is in CN=Computers"
check "OU=Contractors exists under OU=Ridgeline" '_dn "OU=Contractors,OU=Ridgeline,$DOM"' "samba-tool ou --help"
check "WS-TEMP07 is now in OU=Workstations" '_dn "CN=WS-TEMP07,OU=Workstations,OU=Ridgeline,$DOM"' "samba-tool computer --help"
