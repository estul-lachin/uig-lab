# Checks for ransomware-kill-chain (see templates/lab/check.sh for the rules).

I=/root/intel
A=$I/answers.txt
HASHES="7c057430678d2bc6e064616357b2bc9ea8cbc5e0ab91ec496654efff367fe69d 8c70409eadd5c134c2bdcdad8721237b0604fc879189bb7253a960aef8a48671 c0c33d8358a2da9e61719aef02480a58036ab8fbc4a53c8d805c91b60b325b8e"
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_set() { grep . "$1" 2>/dev/null | tr -d " \r" | tr A-Z a-z | sort -u | paste -sd,; }

section "1. IoCs, refanged"
check "iocs/ips.txt holds exactly the three IPv4 addresses" '[ "$(_set $I/iocs/ips.txt)" = 192.0.2.77,198.51.100.23,203.0.113.14 ]' \
  "grep -oE on the defanged form, then sed \"s/\\[\\.\\]/./g\"; sort -u"
check "iocs/domains.txt holds exactly the three domains" '[ "$(_set $I/iocs/domains.txt)" = chat.ntide-support.top,ntide4leaksx7q.onion,update-cdn.top ]' \
  "Only names written with [.]; file names like a.ps1 are not domains"
check "iocs/sha256.txt holds exactly the three hashes" '[ "$(_set $I/iocs/sha256.txt)" = "$(echo $HASHES | tr " " "\n" | sort -u | paste -sd,)" ]' \
  "64 hex characters: grep -oE \"\\b[0-9a-f]{64}\\b\""
check "Nothing is still defanged" 'cat $I/iocs/*.txt 2>/dev/null | grep -q . && ! grep -qE "\[\.\]|hxxp" $I/iocs/*.txt' "Refang everything"

section "2. Mapping the intrusion (map.csv)"
M=$I/map.csv
# _row ID -> "killchain,tactic,technique" normalised: lower case, spaces and underscores as hyphens.
_row() { awk -F, -v id="$1" '$1 == id {print $2 "," $3 "," $4}' $M 2>/dev/null | tr A-Z a-z | tr " _" "--" | tr -d "\r\""; }
# _ok ID "allowed kill chain stages" "tactic" "allowed technique IDs"
_ok() {
  local r kc ta te; r=$(_row "$1"); [ -n "$r" ] || return 1
  kc=${r%%,*}; ta=${r#*,}; ta=${ta%%,*}; te=${r##*,}
  printf "%s\n" $2 | grep -qx -- "$kc" || return 1
  [ "$ta" = "$3" ] || return 1
  for t in $4; do case $te in "$t"|"$t".*) return 0 ;; esac; done; return 1
}
check "map.csv has a header and 12 rows" '[ "$(head -n1 $M 2>/dev/null | tr -d "\r" | tr A-Z a-z)" = "id,killchain,tactic,technique" ] && [ "$(tail -n +2 $M | grep -c .)" = 12 ]' \
  "id,killchain,tactic,technique"
check "1: access bought from a broker" '_ok 1 "reconnaissance weaponization" resource-development "t1650 t1078"' "ATT&CK tactic Resource Development"
check "2: probing the VPN portal" '_ok 2 reconnaissance reconnaissance "t1595"' "Active Scanning"
check "3: VPN login with a stolen password" '_ok 3 "delivery exploitation" initial-access "t1133 t1078"' "External Remote Services / Valid Accounts"
check "4: PowerShell runs the loader" '_ok 4 "exploitation installation" execution "t1059"' "Command and Scripting Interpreter"
check "5: scheduled task at logon" '_ok 5 installation persistence "t1053"' "Scheduled Task/Job"
check "6: HTTPS beacon" '_ok 6 command-and-control command-and-control "t1071"' "Application Layer Protocol"
check "7: lsass dump" '_ok 7 actions-on-objectives credential-access "t1003"' "OS Credential Dumping"
check "8: RDP with a domain admin" '_ok 8 actions-on-objectives lateral-movement "t1021"' "Remote Services"
check "9: AdFind enumeration" '_ok 9 actions-on-objectives discovery "t1087 t1482 t1018"' "Account Discovery"
check "10: rclone upload" '_ok 10 actions-on-objectives exfiltration "t1567 t1048"' "Exfiltration Over Web Service"
check "11: shadow copies deleted" '_ok 11 actions-on-objectives impact "t1490"' "Inhibit System Recovery"
check "12: files encrypted" '_ok 12 actions-on-objectives impact "t1486"' "Data Encrypted for Impact"

section "3. The business behind it"
check "EXTORTION_MODEL is right" '[ "$(_kv $A EXTORTION_MODEL | tr A-Z a-z)" = triple ]' "Encryption, the leak threat, and what happened three days later"
check "AFFILIATE names who did the intrusion" '[ "$(_kv $A AFFILIATE | tr A-Z a-z)" = tern ]' "RaaS: developers vs affiliates"
check "BROKER_EVENT is the timeline id that shows an initial access broker" '[ "$(_kv $A BROKER_EVENT)" = 1 ]' "Who sold the way in?"
check "C2_DOMAIN is the command-and-control domain" '[ "$(_kv $A C2_DOMAIN)" = update-cdn.top ]' "The beacon destination"
