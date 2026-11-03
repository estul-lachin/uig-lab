# Checks for conti-case-study (see templates/lab/check.sh for the rules).

C=/root/case
A=$C/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]" | tr A-Z a-z; }
_in() { local v; v=$(_kv $A "$1"); [ -n "$v" ] && for x in $2; do [ "$v" = "$x" ] && return 0; done; return 1; }

section "1. Conti in brief"
check "GROUP is the threat group behind Conti" '_in GROUP "wizardspider g0102"' "MITRE G0102"
check "EXTENSION is what it appended to files" '[ "$(_kv $A EXTENSION | tr -d .)" = conti ]' "Five letters"
check "RANSOM_NOTE is the note's file name" '_in RANSOM_NOTE "readme.txt conti_readme.txt"' "A .txt in every folder"
check "LEAK_SITE is the name of its leak site" '_in LEAK_SITE "continews"' "Conti ....."

section "2. The intrusion at Mercy Ridge Clinic"
check "LURE is the document that started it" '[ "$(_kv $A LURE)" = patient_referral_0914.doc ]' "A Word file opened from Outlook that started a child process"
check "PATIENT_ZERO is the first host" '[ "$(_kv $A PATIENT_ZERO)" = mrc-ws07 ]' "Where did that document run?"
check "C2_IP is the command-and-control address" '[ "$(_kv $A C2_IP)" = 198.51.100.77 ]' "What the loader keeps connecting to"
check "BEACON_SECONDS is its call-back interval" 'v=$(_kv $A BEACON_SECONDS); [ -n "$v" ] && [ "$v" -ge 55 ] && [ "$v" -le 65 ]' \
  "Gaps between its connections; the median"
check "ESCALATION is how it got domain admin" '_in ESCALATION "zerologon cve-2020-1472"' \
  "An anonymous logon changed the machine account of the DC itself (4742)"
check "EXFIL_DATA is the folder that was stolen" '[ "$(_kv $A EXFIL_DATA)" = "e:\\clinical" ]' "The rclone command line"
check "ENCRYPTED_HOSTS is how many hosts were encrypted" '[ "$(_kv $A ENCRYPTED_HOSTS)" = 5 ]' "Distinct hosts with .CONTI files"
check "SPARED_HOST is the workstation that escaped" '[ "$(_kv $A SPARED_HOST)" = mrc-ws19 ]' "Which workstation in the log never ran the encryptor?"
check "HOURS_TO_IMPACT is from the document to encryption, in whole hours" '_in HOURS_TO_IMPACT "16 17"' "UtcTime of both, subtract"

section "3. The earliest chance to catch it (opportunities.csv)"
O=$C/opportunities.csv
_r() { awk -F, -v s="$1" 'tolower($1) == s {print $2}' $O 2>/dev/null | tr -d " \r"; }
_at() { local r; r=$(_r "$1"); [ -n "$r" ] && for x in $2; do [ "$r" = "$x" ] && return 0; done; return 1; }
check "opportunities.csv has the header stage,record and 8 rows" '[ "$(head -n1 $O 2>/dev/null | tr -d "\r" | tr A-Z a-z)" = stage,record ] && [ "$(tail -n +2 $O | grep -c .)" = 8 ]' \
  "stage,record"
check "delivery" '_at delivery 50119' "The lure being opened"
check "execution" '_at execution 50120' "Its child process"
check "command-and-control" '_at command-and-control 50121' "The first connection to the C2"
check "credential-access" '_at credential-access 50268' "Sysmon 10 on lsass.exe"
check "privilege-escalation" '_at privilege-escalation 50443' "The 4742"
check "lateral-movement" '_at lateral-movement "50456 50548"' "The first network logon as Administrator from the host the attacker controls"
check "exfiltration" '_at exfiltration 50662' "rclone starts"
check "impact" '_at impact "52015 52016"' "The encryptor starts"

section "4. A beacon detector (find-beacons.sh)"
F=$C/find-beacons.sh
_ev() { # RECORD COMPUTER IMAGE IP EPOCH
  printf '{"RecordID":%s,"UtcTime":"%s","Computer":"%s","Channel":"Sysmon","EventID":3,"Image":"%s","DestinationIp":"%s","DestinationPort":443}\n' \
    "$1" "$(date -u -d "@$5" "+%Y-%m-%d %H:%M:%S")" "$2" "$3" "$4"
}
# Traffic the detector has never seen: series A and E are beacons, B, C and D are not.
_unseen() {
  local t=1800000000 i r=1
  for i in $(seq 0 11); do _ev $((r++)) H1 'C:\\Users\\x\\a.exe' 192.0.2.10 $((t + i * 120 + (i * 7 % 23) - 11)); done   # A: 120 s, small jitter
  for i in $(seq 0 5); do _ev $((r++)) H1 'C:\\Users\\x\\b.exe' 192.0.2.11 $((t + i * 60)); done                         # B: regular but only 6
  for g in 5 900 40 1500 12 300 2000 60 8 700 90 30 1200; do t=$((t + g)); _ev $((r++)) H2 'C:\\Apps\\c.exe' 192.0.2.12 $t; done  # C: bursty
  t=1800000000; for g in 30 30 30 30 300 30 30 30 30; do t=$((t + g)); _ev $((r++)) H2 'C:\\Apps\\d.exe' 192.0.2.13 $t; done        # D: one long pause
  t=1800000000; for i in $(seq 0 8); do _ev $((r++)) H3 'C:\\ProgramData\\e.exe' 192.0.2.14 $((t + i * 900)); done                  # E: every 15 min
  printf '{"RecordID":99,"UtcTime":"2027-01-15 08:00:00","Computer":"H1","Channel":"Sysmon","EventID":1,"Image":"C:\\\\Users\\\\x\\\\a.exe","CommandLine":"a.exe"}\n'
}
_out() { bash $F 2>/dev/null | tr -d "\r" | grep . | sort -u; }
check "find-beacons.sh exists and is executable" '[ -x $F ]' "chmod +x"
check "On the case file it flags exactly the six regular series" '[ -x $F ] && [ "$(_out < $C/events.jsonl | wc -l)" = 6 ] && _out < $C/events.jsonl | grep -qxF "MRC-WS07,C:\\Windows\\System32\\rundll32.exe,198.51.100.77"' \
  "Group by Computer, Image and DestinationIp; at least 8 connections; every gap within 25% of the median"
check "On traffic it has never seen it flags exactly the two beacons" '[ -x $F ] && [ "$(_unseen | _out | cut -d, -f1,3 | paste -sd" ")" = "H1,192.0.2.10 H3,192.0.2.14" ]' \
  "Too few connections, bursty gaps, or one long pause: none of those is a beacon"
