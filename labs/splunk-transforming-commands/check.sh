# Checks for splunk-transforming-commands (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk over its REST API.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=6361   # 5286 shop events + 1075 from web-03
A=/root/answers.txt
W="search index=main sourcetype=access_combined"
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u $AUTH --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tr -d '"\r'; }
_val() { _spl "$1" | tail -n +2; }
_busiest() { _val "$W | stats count by clientip | sort - count | head 1 | table clientip"; }

for _ in $(seq 1 60); do [ "$(_val "| tstats count where index=main")" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_val "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. top and rare"
check "BUSIEST_CLIENT: the clientip with the most requests" '[ "$(_kv $A BUSIEST_CLIENT)" = "$(_busiest)" ]' "| top clientip"
check "BUSIEST_PATHS: distinct uri_path values that client requested" '[ "$(_kv $A BUSIEST_PATHS)" = "$(_val "$W clientip=$(_busiest) | stats dc(uri_path)")" ]' \
  "dc(uri_path) for that client; what kind of client is it?"
check "RAREST_CLIENT: the clientip with the fewest requests" '[ "$(_kv $A RAREST_CLIENT)" = 192.0.2.199 ]' "| rare clientip"
check "RARE_DOWNLOAD: the biggest thing that client got" '[ "$(_kv $A RARE_DOWNLOAD)" = /backup/shop-db-2026-10.sql.gz ]' \
  "Its events: uri_path and bytes; did the WAF stop it?"

section "2. stats"
check "SERVER_ERRORS: access_combined events with status 500 or higher" '[ "$(_kv $A SERVER_ERRORS)" = "$(_val "$W status>=500 | stats count")" ]' "status>=500 | stats count"
check "TOP_403_CLIENT: the clientip blocked (403) most often" '[ "$(_kv $A TOP_403_CLIENT)" = "$(_val "$W status=403 | stats count by clientip | sort - count | head 1 | table clientip")" ]' \
  "status=403, then count by clientip"

section "3. A per-client profile"
_profile() { _spl "| savedsearch \"client-profile\""; }
check "A report named client-profile exists" 'curl -sk -u $AUTH -o /dev/null -w "%{http_code}" "$API/servicesNS/admin/search/saved/searches/client-profile" | grep -q 200' "Save As > Report"
check "...its columns are clientip, hits, paths and methods" '[ "$(_profile | head -n1 | tr "," "\n" | grep -v "^_" | sort | paste -sd,)" = clientip,hits,methods,paths ]' \
  "stats count AS hits, dc(uri_path) AS paths, values(method) AS methods by clientip"
check "...sorted by hits, most first, over all time" '[ "$(_profile | sed -n 2p | cut -d, -f1)" = "$(_busiest)" ]' \
  "stats does not sort: add | sort - hits; save it with All time"
