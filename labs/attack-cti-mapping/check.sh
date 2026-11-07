# Checks for attack-cti-mapping (see templates/lab/check.sh for the rules).
# The learner maps a prose report to ATT&CK technique IDs in /root/answers.txt.
# Every check is default-false: a fresh answers file is blank, so nothing passes.
# Each mapping accepts the parent technique id OR the exact sub-technique id.

ANS=/root/answers.txt
val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
# lowercase and drop everything but letters+digits, so "T1566.001" -> "t1566001"
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9' ; }
want() { printf '%s' "$(norm "$(val "$1")")" | grep -qE "$2"; }

section "1. Map the report to technique IDs"
check "1. spearphishing attachment -> T1566.001" 'want MAP_1 "^t1566(001)?$"' "Phishing: Spearphishing Attachment"
check "2. macro runs PowerShell -> T1059.001" 'want MAP_2 "^t1059(001)?$"' "Command and Scripting Interpreter: PowerShell"
check "3. scheduled task at logon -> T1053.005" 'want MAP_3 "^t1053(005)?$"' "Scheduled Task/Job: Scheduled Task"
check "4. LSASS dump with Mimikatz -> T1003.001" 'want MAP_4 "^t1003(001)?$"' "OS Credential Dumping: LSASS Memory"
check "5. net group Domain Admins enum -> T1087.002" 'want MAP_5 "^t1087(002)?$"' "Account Discovery: Domain Account"
check "6. lateral move over SMB admin shares -> T1021.002" 'want MAP_6 "^t1021(002)?$"' "Remote Services: SMB/Windows Admin Shares"
check "7. HTTPS C2 beacon -> T1071.001" 'want MAP_7 "^t1071(001)?$"' "Application Layer Protocol: Web Protocols"
check "8. exfiltration over the C2 channel -> T1041" 'want MAP_8 "^t1041$"' "Exfiltration Over C2 Channel"
check "9. cleared Windows event logs -> T1070.001" 'want MAP_9 "^t1070(001)?$"' "Indicator Removal: Clear Windows Event Logs"
check "10. ransomware encryption -> T1486" 'want MAP_10 "^t1486$"' "Data Encrypted for Impact"

section "2. The ATT&CK ecosystem"
check "ATOMIC: Atomic Red Team" 'want ATOMIC "atomic"' "Red Canary's single-technique test library"
check "EMULATION: CALDERA" 'want EMULATION "caldera"' "MITRE's automated adversary-emulation platform"
check "DEFENSE: D3FEND" 'want DEFENSE "d3fend"' "MITRE's defensive-countermeasure knowledge graph"
check "PURPLE: purple teaming" 'want PURPLE "purple"' "red + blue working together on ATT&CK common ground"
check "STIX: the machine-readable format (STIX/TAXII)" 'want STIX "stix|taxii"' "how ATT&CK is published for tools to ingest"
