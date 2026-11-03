# Checks for ransomware-qr-phishing (see templates/lab/check.sh for the rules).

L=/root/case/logs
A=/root/case/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_is() { [ "$(_kv $A "$1")" = "$2" ]; }
# An ATT&CK answer is right if it names one of the accepted techniques (sub-techniques of them count).
_att() { local v; v=$(_kv $A "$1" | tr a-z A-Z); [ -n "$v" ] || return 1; shift; for t in "$@"; do case $v in "$t"|"$t".*) return 0 ;; esac; done; return 1; }

section "1. The phishing mail"
check "PHISH_SENDER is right" '_is PHISH_SENDER benefits@lumen-hr-benefits.com' "jq 'select(.qr_code_url != null)' mail.jsonl"
check "QR_DOMAIN is the domain the QR code leads to" '_is QR_DOMAIN lumen-benefits-portal.com' "The host part of qr_code_url"
check "PHISH_RECIPIENTS is how many people received it" '_is PHISH_RECIPIENTS "$(jq -r "select(.qr_code_url != null) | .to" $L/mail.jsonl | sort -u | wc -l)"' "Count the distinct .to values"

section "2. Initial access and MFA fatigue"
check "ATTACKER_IP is right" '_is ATTACKER_IP 203.0.113.80' "Which address logs in as priya.n from an unusual country?"
check "MFA_PUSHES counts the pushes sent before one was approved (including it)" '_is MFA_PUSHES "$(jq -r "select(.event == \"mfa_push_sent\" and .user == \"priya.n\") | .time" $L/idp.jsonl | wc -l)"' \
  "select(.event == \"mfa_push_sent\")"
check "APPROVED_AT is the time of the approval" '_is APPROVED_AT "$(jq -r "select(.event == \"mfa_push_approved\") | .time" $L/idp.jsonl)"' "As written in the log, e.g. 2026-10-21T08:00:00Z"

section "3. Persistence"
check "NEW_ADMIN is the account the attacker created" '_is NEW_ADMIN svc-backup2' "jq 'select(.action == \"account_created\")' directory.jsonl"
check "ADMIN_GROUP is the group it was put in" '[ "$(_kv $A ADMIN_GROUP | tr A-Z a-z)" = domainadmins ]' "The next directory event for that account"
check "CREATED_BY is the account that did it" '_is CREATED_BY priya.n' "The actor field"

section "4. Execution"
check "PS_HOST is where the encoded PowerShell ran" '_is PS_HOST FIN-WS-07' "jq 'select(.command_line | test(\"-enc\"))' endpoint.jsonl"
check "STAGING_FILE is the archive it built" '[ "$(_kv $A STAGING_FILE | tr A-Z a-z)" = "c:\\users\\public\\q3.zip" ]' \
  "-enc takes base64 of UTF-16LE text: base64 -d | iconv -f UTF-16LE -t UTF-8"
check "/root/case/decoded.txt holds the decoded command" 'grep -q "Compress-Archive" /root/case/decoded.txt 2>/dev/null && grep -q "Invoke-WebRequest" /root/case/decoded.txt' "Save the decoded text there"

section "5. Exfiltration"
check "EXFIL_DOMAIN is where the data went" '_is EXFIL_DOMAIN files.drop-share.net' "In the decoded command and in proxy.jsonl"
check "EXFIL_MB is the total uploaded to it, in MiB" '_is EXFIL_MB "$(jq -s "[.[] | select(.dest == \"files.drop-share.net\") | .bytes_out] | add / 1048576 | floor" $L/proxy.jsonl)"' \
  "jq -s '[.[] | select(...) | .bytes_out] | add / 1048576'"

section "6. Mapping to MITRE ATT&CK"
check "ATT_INITIAL_ACCESS: the QR-code phishing mail" '_att ATT_INITIAL_ACCESS T1566' "Phishing, link variant"
check "ATT_MFA: the flood of push requests" '_att ATT_MFA T1621' "Multi-Factor Authentication Request Generation"
check "ATT_LOGIN: logging in with the stolen credentials" '_att ATT_LOGIN T1078' "Valid Accounts"
check "ATT_PERSISTENCE: the new admin account" '_att ATT_PERSISTENCE T1136 T1098' "Create Account (or Account Manipulation for the group change)"
check "ATT_EXECUTION: the PowerShell" '_att ATT_EXECUTION T1059' "Command and Scripting Interpreter: PowerShell"
check "ATT_EXFIL: the upload" '_att ATT_EXFIL T1567 T1048 T1041' "Exfiltration Over Web Service (to cloud storage)"

section "7. Immediate response"
R=/root/case/response.md
check "response.md names the actions for each piece of evidence" '[ -f $R ] && grep -qi "svc-backup2" $R && grep -qi "priya" $R && grep -qi "FIN-WS-07" $R && grep -qiE "drop-share|lumen-benefits-portal|203\.0\.113\.80" $R' \
  "At least: the new admin account, priya's account and sessions, the workstation, and what to block"
check "It has at least five separate actions" '[ "$(grep -cE "^[[:space:]]*([-*]|[0-9]+\.) " $R 2>/dev/null)" -ge 5 ]' "One bullet per action"

section "8. The four public cases"
check "CASE_WANNACRY: how it got in" '_att CASE_WANNACRY T1210 T1190' "An SMB vulnerability on unpatched hosts"
check "CASE_COLONIAL: how it got in" '_att CASE_COLONIAL T1133 T1078' "A VPN account without MFA"
check "CASE_MGM: how it got in" '_att CASE_MGM T1566 T1656 T1078' "A phone call to the helpdesk, posing as an employee"
check "CASE_CHANGE: how it got in" '_att CASE_CHANGE T1133 T1078 T1199' "Remote access with stolen credentials, no MFA"
