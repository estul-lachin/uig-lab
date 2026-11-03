# Checks for lockbit-case-study (see templates/lab/check.sh for the rules).

C=/root/case
A=$C/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]" | tr A-Z a-z; }

section "1. LockBit in brief"
check "EXFIL_TOOL is a tool LockBit used to steal data" 'case "$(_kv $A EXFIL_TOOL)" in stealbit|rclone) true ;; *) false ;; esac' \
  "Its own one came with 2.0"
check "SPREAD_PROTOCOL is the protocol it spreads over" '[ "$(_kv $A SPREAD_PROTOCOL)" = smb ]' "Admin shares, PsExec, Group Policy"
check "FIRST_EXT and SECOND_EXT are its first two file extensions" '[ "$(_kv $A FIRST_EXT | tr -d .)" = abcd ] && [ "$(_kv $A SECOND_EXT | tr -d .)" = lockbit ]' \
  "Before the name, and when it got the name"
check "TAKEDOWN is the 2024 law-enforcement operation" 'case "$(_kv $A TAKEDOWN)" in cronos|operationcronos) true ;; *) false ;; esac' "February 2024, NCA and FBI"

section "2. The night at Harbor Lane Logistics"
check "ATTACKER_IP is where the intrusion came from" '[ "$(_kv $A ATTACKER_IP)" = 203.0.113.61 ]' "Security 4625 then 4624, LogonType 10"
check "ENTRY_ACCOUNT is the account it got in with" '[ "$(_kv $A ENTRY_ACCOUNT)" = svc_scan ]' "The 4624 right after the failures"
check "ENTRY_HOST is the first host it got into" '[ "$(_kv $A ENTRY_HOST)" = hll-rds01 ]' "Computer of that 4624"
check "ADMIN_ACCOUNT is the privileged account it moved with" '[ "$(_kv $A ADMIN_ACCOUNT)" = adm.jkeller ]' "Who ran PsExec?"
check "EXFIL_DATA is the folder that was stolen" '[ "$(_kv $A EXFIL_DATA)" = "d:\\shares\\finance" ]' "The rclone command line"
check "ENCRYPTED_HOSTS is how many hosts were encrypted" '[ "$(_kv $A ENCRYPTED_HOSTS)" = 3 ]' "Hosts with files renamed by the encryptor"
check "SPARED_HOST is the workstation that escaped" '[ "$(_kv $A SPARED_HOST)" = hll-ws031 ]' "Which workstation in the log never ran it?"
check "RANSOM_EXT is the extension it added" '[ "$(_kv $A RANSOM_EXT | tr -d .)" = k9f2hqz1p ]' "Sysmon 11, TargetFilename"

section "3. ATT&CK (map.csv)"
M=$C/map.csv
_t() { awk -F, -v id="$1" '$1 == id {print $2}' $M 2>/dev/null | tr -d " \r\"" | tr a-z A-Z; }
# _ok RECORD "allowed technique IDs" (a sub-technique of an allowed ID counts)
_ok() { local t; t=$(_t "$1"); [ -n "$t" ] || return 1; for x in $2; do case $t in "$x"|"$x".*) return 0 ;; esac; done; return 1; }
check "map.csv has the header record,technique and 10 rows" '[ "$(head -n1 $M 2>/dev/null | tr -d "\r" | tr A-Z a-z)" = record,technique ] && [ "$(tail -n +2 $M | grep -c .)" = 10 ]' \
  "record,technique"
check "10172: the RDP logon" '_ok 10172 "T1078 T1133 T1021"' "Valid Accounts"
check "10236: netscan" '_ok 10236 "T1046 T1018"' "Discovery"
check "10272: comsvcs.dll MiniDump" '_ok 10272 "T1003"' "Credential Access"
check "10346: PsExec" '_ok 10346 "T1021 T1569 T1570"' "Lateral Movement"
check "10438: rclone to Mega" '_ok 10438 "T1567 T1048"' "Exfiltration"
check "10629: New-GPO" '_ok 10629 "T1484"' "Domain or Tenant Policy Modification"
check "10689: vssadmin" '_ok 10689 "T1490"' "Impact"
check "10690: wevtutil" '_ok 10690 "T1070"' "Defense Evasion"
check "10700: the wallpaper" '_ok 10700 "T1491"' "Impact"
check "10693: a renamed document" '_ok 10693 "T1486"' "Impact"

section "4. A detection (detect-shadow.sh)"
D=$C/detect-shadow.sh
_lab() { [ -x $D ] && bash $D < $C/events.jsonl 2>/dev/null | tr -d " \r" | grep . | sort -u | paste -sd,; }
# Events the detection has never seen: what it must flag (1-4) and must not (5-8).
_unseen() {
  printf '%s\n' \
    '{"RecordID":1,"Computer":"T","Channel":"Sysmon","EventID":1,"Image":"C:\\Windows\\System32\\vssadmin.exe","CommandLine":"vssadmin.exe Delete Shadows /For=C: /Quiet","ParentImage":"C:\\x\\a.exe","User":"T\\u"}' \
    '{"RecordID":2,"Computer":"T","Channel":"Sysmon","EventID":1,"Image":"C:\\Windows\\System32\\wbem\\WMIC.exe","CommandLine":"wmic shadowcopy delete /nointeractive","ParentImage":"C:\\x\\a.exe","User":"T\\u"}' \
    '{"RecordID":3,"Computer":"T","Channel":"Sysmon","EventID":1,"Image":"C:\\WINDOWS\\SYSTEM32\\VSSADMIN.EXE","CommandLine":"VSSADMIN.EXE resize shadowstorage /for=c: /on=c: /maxsize=401MB","ParentImage":"C:\\x\\b.exe","User":"T\\u"}' \
    '{"RecordID":4,"Computer":"T","Channel":"Sysmon","EventID":1,"Image":"C:\\Windows\\System32\\vssadmin.exe","CommandLine":"vssadmin   delete   shadows /all","ParentImage":"C:\\x\\c.exe","User":"T\\u"}' \
    '{"RecordID":5,"Computer":"T","Channel":"Sysmon","EventID":1,"Image":"C:\\Windows\\System32\\vssadmin.exe","CommandLine":"vssadmin.exe list shadows","ParentImage":"C:\\x\\d.exe","User":"T\\u"}' \
    '{"RecordID":6,"Computer":"T","Channel":"Sysmon","EventID":1,"Image":"C:\\Windows\\notepad.exe","CommandLine":"notepad.exe C:\\kb\\vssadmin delete shadows - why it matters.txt","ParentImage":"C:\\Windows\\explorer.exe","User":"T\\u"}' \
    '{"RecordID":7,"Computer":"T","Channel":"Sysmon","EventID":11,"Image":"C:\\Windows\\System32\\vssadmin.exe","TargetFilename":"C:\\Temp\\delete shadows.log"}' \
    '{"RecordID":8,"Computer":"T","Channel":"Sysmon","EventID":1,"Image":"C:\\Windows\\System32\\wbem\\WMIC.exe","CommandLine":"wmic shadowcopy list brief","ParentImage":"C:\\x\\e.exe","User":"T\\u"}'
}
check "detect-shadow.sh exists and is executable" '[ -x $D ]' "chmod +x"
check "On the case file it flags exactly the three shadow-copy deletions" '[ "$(_lab)" = 10689,10706,10723 ]' \
  "Read stdin with jq, print the RecordID of each match on its own line"
check "On events it has never seen it flags exactly the right ones" '[ -x $D ] && [ "$(_unseen | bash $D 2>/dev/null | tr -d " \r" | grep . | sort -u | paste -sd,)" = 1,2,3,4 ]' \
  "Case does not matter on Windows; look at the process image, not just the words; resizing shadow storage to almost nothing deletes them too"
