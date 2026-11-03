# Checks for splunk-spl-fundamentals (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk the same questions over its REST API.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=5286
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u $AUTH --max-time 60 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
_cnt() { _spl "search index=main $1 | stats count"; }
A=/root/answers.txt
W="sourcetype=access_combined"

for _ in $(seq 1 60); do [ "$(_spl "| tstats count where index=main")" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_spl "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. Terms, phrases and booleans"
check "TERM_FAILED: linux_secure events containing the term failed" '[ "$(_kv $A TERM_FAILED)" = "$(_cnt "sourcetype=linux_secure failed")" ]' "Terms ignore case; All time"
check "PHRASE_ROOT: events with the exact phrase failed password for root" '[ "$(_kv $A PHRASE_ROOT)" = "$(_cnt "sourcetype=linux_secure \"failed password for root\"")" ]' "Quotes make a phrase"
check "OK_OR_NOT_MODIFIED: access_combined events with status 200 or 304" '[ "$(_kv $A OK_OR_NOT_MODIFIED)" = "$(_cnt "$W (status=200 OR status=304)")" ]' "OR in upper case, in parentheses"
check "LOWERCASE_OR: the same search written with a lower-case or" '[ "$(_kv $A LOWERCASE_OR)" = "$(_cnt "$W status=200 or status=304")" ]' \
  "Run it and compare: or in lower case is just another term, ANDed with the rest"
check "NOT_200: access_combined events that are not status 200" '[ "$(_kv $A NOT_200)" = "$(_cnt "$W NOT status=200")" ]' "NOT status=200"

section "2. Field filters"
check "COUNT_404: access_combined events with status 404" '[ "$(_kv $A COUNT_404)" = "$(_cnt "$W status=404")" ]' "status=404"
check "BIG_RESPONSES: access_combined events of 20000 bytes or more" '[ "$(_kv $A BIG_RESPONSES)" = "$(_cnt "$W bytes>=20000")" ]' "bytes>=20000 compares numbers"
check "DISTINCT_CLIENTS: distinct clientip values in access_combined" '[ "$(_kv $A DISTINCT_CLIENTS)" = "$(_spl "search index=main $W | stats dc(clientip)")" ]' "stats dc(clientip), or dedup clientip and count"

section "3. Shaping results"
check "FIRST_ERROR_PATH: the uri_path of the earliest 5xx response" '[ "$(_kv $A FIRST_ERROR_PATH)" = "$(_spl "search index=main $W status>=500 | sort _time | head 1 | table uri_path")" ]' \
  "status>=500 | table _time clientip status uri_path | sort _time"
check "Report web-errors exists" 'curl -sk -u $AUTH -o /dev/null -w "%{http_code}" "$API/servicesNS/admin/search/saved/searches/web-errors" | grep -q 200' "Save As > Report, name web-errors"
check "...it counts 4xx and 5xx responses per path, with a column named path" '_spl "| savedsearch \"web-errors\"" | head -n1 | grep -q "^/wp-login.php," && curl -sk -u $AUTH "$API/services/search/jobs/export" --data-urlencode "search=| savedsearch \"web-errors\"" -d output_mode=csv -d earliest_time=0 | head -n1 | tr -d "\"\r" | grep -qx "path,count"' \
  "status>=400 | stats count by uri_path | rename uri_path AS path | sort -count; time range All time"
