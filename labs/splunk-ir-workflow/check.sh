# Checks for splunk-ir-workflow (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk over its REST API.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=904
A=/root/answers.txt
WIN="index=main sourcetype=wineventlog:json"
FW="index=main sourcetype=fw:traffic"
IP=10.40.2.57
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u $AUTH --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
# The IR report: a saved search named ir_<initials>, as JSON
_rep() { curl -sk -u $AUTH -G "$API/servicesNS/-/-/saved/searches" -d output_mode=json -d count=0 2>/dev/null | jq -c '[.entry[] | select(.name | test("^ir_[a-z]{2,4}$"))][0] // empty'; }
_rname() { _rep | jq -r .name; }
_rrun() { _spl "| savedsearch \"$(_rname)\" | $1"; }

for _ in $(seq 1 60); do [ "$(_spl "| tstats count where index=main")" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_spl "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. Triage"
check "SUSPICIOUS_SRC: the non-DC address it_admin logged on to DC-01 from" '[ "$(_kv $A SUSPICIOUS_SRC)" = $IP ]' \
  "EventID=4624 TargetUserName=it_admin Computer=DC-01*, then stats count by IpAddress WorkstationName"
check "SUSPICIOUS_LOGONS: such logons" '[ "$(_kv $A SUSPICIOUS_LOGONS)" = "$(_spl "search $WIN EventID=4624 TargetUserName=it_admin Computer=DC-01* IpAddress=$IP | stats count")" ]' "Only that address"
check "LOGON_TYPE: their logon type" '[ "$(_kv $A LOGON_TYPE)" = 3 ]' "LogonType: 2 is at the keyboard, 3 over the network, 10 remote desktop"

section "2. Pivot"
check "SRC_WORKSTATION: the machine behind that address" '[ "$(_kv $A SRC_WORKSTATION)" = WS-HR-07 ]' "WorkstationName in the same events"
check "IP_SOURCETYPES: sourcetypes that mention the address" '[ "$(_kv $A IP_SOURCETYPES)" = "$(_spl "search index=* \"$IP\" | stats dc(sourcetype)")" ]' "index=* and the address, stats values(sourcetype)"
check "HOST_ONLY_EVENTS: events naming the workstation but not its address" '[ "$(_kv $A HOST_ONLY_EVENTS)" = "$(_spl "search index=main \"WS-HR-07\" NOT \"$IP\" | stats count")" ]' \
  "Windows events are collected by wec-01: the machine is in Computer, not in host"
check "C2_IP: where the workstation beacons to, every minute" '[ "$(_kv $A C2_IP)" = 198.51.100.23 ]' "fw:traffic from the address: same destination, small, regular"

section "3. The timeline"
check "PATIENT_ZERO_USER: who was logged on to the workstation" '[ "$(_kv $A PATIENT_ZERO_USER)" = lhart ]' "4624 with LogonType 2 on that Computer"
check "PHISH_FILE: the document that started it" '[ "$(_kv $A PHISH_FILE)" = invoice-3381.docm ]' "4688: what did Word open, just before PowerShell?"
check "FIRST_OBSERVED: the time of that first malicious event (UTC, HH:MM:SS)" '[ "$(_kv $A FIRST_OBSERVED)" = 09:03:41 ]' "The lab Splunk shows times in UTC"
check "BRUTE_FAILS: failed logons for it_admin from the workstation" '[ "$(_kv $A BRUTE_FAILS)" = "$(_spl "search $WIN EventID=4625 TargetUserName=it_admin IpAddress=$IP | stats count")" ]' "EventID 4625"
check "LATERAL_HOST: the other server it_admin logged on to from there" '[ "$(_kv $A LATERAL_HOST)" = FS-01 ]' "4624 from the address, Computer other than DC-01"
check "STAGED_ARCHIVE: the archive the attacker built" '[ "$(_kv $A STAGED_ARCHIVE)" = "C:\\Users\\Public\\q4-fin.7z" ]' "CommandLine of 7z.exe; the full path"
check "EXFIL_IP: where the archive went" '[ "$(_kv $A EXFIL_IP)" = 203.0.113.200 ]' "fw:traffic from the address, sort - bytes_out"

section "4. Document"
check "A report named ir_<your initials> exists, shared with the app" '[ -n "$(_rname)" ] && _rep | jq -e ".acl.sharing == \"app\" or .acl.sharing == \"global\"" >/dev/null' \
  "Save As > Report, title ir_ plus two to four lowercase initials; Edit Permissions: This app only"
check "...it returns every event about the workstation: address and name" '[ -n "$(_rname)" ] && [ "$(_rrun "stats count")" = "$(_spl "search index=main (\"$IP\" OR \"WS-HR-07\") | stats count")" ]' \
  "Search for the address OR the host name, over All time"
check "...as a timeline: _time and sourcetype, oldest first" '[ -n "$(_rname)" ] && [ "$(_rrun "head 1 | eval ok=if(isnotnull(sourcetype), 1, 0) | table ok")" = 1 ] && [ "$(_rrun "streamstats current=f last(_time) AS prev | where _time < prev | stats count")" = 0 ] && [ "$(_rrun "stats min(_time) AS m | eval m=strftime(m, \"%H:%M:%S\") | table m")" = "$(_rrun "head 1 | eval m=strftime(_time, \"%H:%M:%S\") | table m")" ]' \
  "table _time sourcetype ... and sort _time (sort without a minus is oldest first)"
check "...and carries the ticket: ir_status=contained, ir_ticket=INC-2026-1103" '[ -n "$(_rname)" ] && [ "$(_rrun "where ir_status==\"contained\" AND ir_ticket==\"INC-2026-1103\" | stats count")" = "$(_rrun "stats count")" ]' \
  "eval ir_status=..., ir_ticket=... in the search"
