# Checks for ad-authentication (see templates/lab/check.sh for the rules).
# Runs on DC01. Knowledge answers are fixed; the SPN is read live; log answers are computed from the log.

A=/root/answers.txt
LOG=/var/log/dc01/security.log
PASS='Lab-AD-2026!'
_kv() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
_n() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-'; }
_any() { _v=$(_kv "$1"); shift; [ -n "$_v" ] || return 1; for _e in "$@"; do [ "$(_n "$_v")" = "$(_n "$_e")" ] && return 0; done; return 1; }
# field VALUE from a set of log lines on stdin: _field EventID=4740 TargetUser
_ev() { grep "EventID=$1" "$LOG"; }

section "1. The two protocols (the course questions)"
check "AUTH_DEFAULT: the default authentication protocol in AD" '_any AUTH_DEFAULT Kerberos' "Ticket-based; the KDC runs on the DC"
check "LEGACY_PROTOCOL: the older challenge-response protocol behind Pass-the-Hash" '_any LEGACY_PROTOCOL NTLM' "Four letters"
check "TICKET_CMD: the command that lists your cached Kerberos tickets" '_any TICKET_CMD klist' "Try it after kinit"

section "2. The Event IDs every analyst knows"
check "EVT_LOGON_SUCCESS: a successful logon" '_any EVT_LOGON_SUCCESS 4624' "46xx"
check "EVT_LOGON_FAIL: a failed logon (a spike means brute force)" '_any EVT_LOGON_FAIL 4625' "One more than success"
check "EVT_TGT: a Kerberos TGT requested (AS-REQ)" '_any EVT_TGT 4768' "The authentication itself"
check "EVT_TGS: a Kerberos service ticket requested (TGS-REQ) - the event Kerberoasting floods" '_any EVT_TGS 4769' "One more than the TGT event"
check "EVT_LOCKOUT: an account locked out" '_any EVT_LOCKOUT 4740' "47xx"
check "RDP_LOGON_TYPE: the Logon Type for a Remote Desktop logon" '_any RDP_LOGON_TYPE 10' "2 is interactive, 3 is network"

section "3. The Kerberoastable account (live on the DC)"
check "KERBEROASTABLE_ACCOUNT: the seeded account with an SPN" '_any KERBEROASTABLE_ACCOUNT svc_sql "ridgeline\\svc_sql"' \
  "samba-tool spn list <account>; which service account has one?"
check "SPN: its Service Principal Name" '_any SPN MSSQLSvc/sql.ridgeline.local MSSQLSvc/sql.ridgeline.local:1433' \
  "samba-tool spn list svc_sql; the MSSQLSvc one"

section "4. Triage the Security log"
check "ATTACKER_IP: the address behind the brute force, lockout and Kerberoasting" '_any ATTACKER_IP 10.203.19.88' \
  "One IP shows up in the 4625 burst, the 4740 and the 4769 burst"
check "BRUTE_ACCOUNT: the account the 4625 burst targeted" '_any BRUTE_ACCOUNT svc_backup' \
  "grep EventID=4625, group by TargetUser; which one repeats from the attacker?"
check "BRUTE_FAILS: how many 4625 that account got from the attacker" '_any BRUTE_FAILS "$(_ev 4625 | grep svc_backup | grep -c 10.203.19.88)"' \
  "grep 4625, the target account and the attacker IP, then count"
check "LOCKOUT_ACCOUNT: the account the 4740 names" '_any LOCKOUT_ACCOUNT svc_backup' "grep EventID=4740"
check "KROAST_COUNT: how many 4769 requested the MSSQL service" '_any KROAST_COUNT "$(_ev 4769 | grep -c MSSQLSvc)"' \
  "grep EventID=4769 for the SPN and count; the background has none for it"
check "KROAST_ENC: the TicketEncryption on those requests (the weak one)" '_any KROAST_ENC 0x17 RC4 rc4-hmac' \
  "0x17 is RC4; 0x12 is AES256. The weak type is what makes offline cracking feasible"
check "PTH_ACCOUNT: the account in the NTLM network logon (4624, Type 3) from the attacker" '_any PTH_ACCOUNT mreyes' \
  "grep EventID=4624 with AuthPackage=NTLM and the attacker IP"
