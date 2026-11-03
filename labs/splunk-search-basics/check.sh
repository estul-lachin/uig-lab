# Checks for splunk-search-basics (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk the same questions over its REST API.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=5286   # events the lab generates
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u $AUTH --max-time 60 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
A=/root/answers.txt

# Wait for Splunk and for the first full indexing (only slow right after the very first start).
for _ in $(seq 1 60); do
  [ "$(_spl "| tstats count where index=main")" = "$TOTAL" ] && break
  sleep 5
done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_spl "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1-5. The course questions"
check "COUNT_ACCESS: events in access_combined" '[ "$(_kv $A COUNT_ACCESS)" = "$(_spl "| tstats count where index=main sourcetype=access_combined")" ]' \
  "index=main sourcetype=access_combined, time picker on All time"
check "SOURCETYPES: how many sourcetypes feed main" '[ "$(_kv $A SOURCETYPES)" = "$(_spl "| metadata type=sourcetypes index=main | stats count")" ]' "| metadata type=sourcetypes index=main"
check "STATUS_VALUES: distinct values of status in access_combined" '[ "$(_kv $A STATUS_VALUES)" = "$(_spl "search index=main sourcetype=access_combined | stats dc(status)")" ]' \
  "Fields sidebar > status, or | stats dc(status)"
check "SMART_TAB: where Smart Mode puts a transforming search" '[ "$(_kv $A SMART_TAB | tr A-Z a-z)" = statistics ]' "Run one with | stats count and look"
check "COUNT_SECURE: events in linux_secure" '[ "$(_kv $A COUNT_SECURE)" = "$(_spl "| tstats count where index=main sourcetype=linux_secure")" ]' "All time"

section "6. An exact time window"
check "WINDOW_COUNT: access_combined events from 2026-10-29 03:00:00 to 03:30:00 UTC" '[ "$(_kv $A WINDOW_COUNT)" = "$(_spl "search index=main sourcetype=access_combined earliest=\"10/29/2026:03:00:00\" latest=\"10/29/2026:03:30:00\" | stats count")" ]' \
  "Time picker > Date & Time Range; the times are UTC (the lab's Splunk runs in UTC)"

section "7. The hunt"
check "BRUTE_IP: the source of the SSH password guessing" '[ "$(_kv $A BRUTE_IP)" = 203.0.113.50 ]' "linux_secure has no src field here: | rex \"from (?<src_ip>\\S+) port\" | stats count by src_ip"
check "BREACHED_USER: the account it then logged in as" '[ "$(_kv $A BREACHED_USER)" = deploy ]' "Accepted ... from that address"
check "SCANNER_IP: the source probing for /wp-login.php" '[ "$(_kv $A SCANNER_IP)" = 198.51.100.77 ]' "sourcetype=access_combined uri_path=\"/wp-login.php\" | stats count by clientip"
check "SCANNER_SIGNATURE: the IDS signature that fired for it most" '[ "$(_kv $A SCANNER_SIGNATURE | tr -d " ")" = "ETSCANPossibleWordPressloginscan" ]' \
  "sourcetype=suricata src_ip=<scanner> | top alert.signature"
check "Report ssh-failures-by-src exists in Search & Reporting" 'curl -sk -u $AUTH -o /dev/null -w "%{http_code}" "$API/servicesNS/admin/search/saved/searches/ssh-failures-by-src" | grep -q 200' \
  "Save As > Report, name ssh-failures-by-src"
check "...and its first row is the brute-force source" '_spl "| savedsearch \"ssh-failures-by-src\"" | head -n1 | grep -q "203.0.113.50"' \
  "Failed password events, rex out the address, | stats count by it | sort - count; time range All time"

# Optional: only when the owner has put their own data in private-data/ (index private, local only).
if [ "$(_spl "| tstats count where index=private")" -gt 0 ] 2>/dev/null; then
  section "8. Your private data (index=private)"
  check "PRIVATE_COUNT_ACCESS: access_combined events in the private index" '[ "$(_kv $A PRIVATE_COUNT_ACCESS)" = "$(_spl "| tstats count where index=private sourcetype=access_combined")" ]' "index=private sourcetype=access_combined, All time"
  check "PRIVATE_SOURCETYPES: sourcetypes in the private index" '[ "$(_kv $A PRIVATE_SOURCETYPES)" = "$(_spl "| metadata type=sourcetypes index=private | stats count")" ]' "| metadata type=sourcetypes index=private"
  check "PRIVATE_STATUS_VALUES: distinct status values in its access_combined" '[ "$(_kv $A PRIVATE_STATUS_VALUES)" = "$(_spl "search index=private sourcetype=access_combined | stats dc(status)")" ]' "| stats dc(status)"
  check "PRIVATE_COUNT_SECURE: linux_secure events in the private index" '[ "$(_kv $A PRIVATE_COUNT_SECURE)" = "$(_spl "| tstats count where index=private sourcetype=linux_secure")" ]' "All time"
fi
