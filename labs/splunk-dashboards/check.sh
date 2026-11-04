# Checks for splunk-dashboards (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk over its REST API.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=6429   # 5286 shop events + 1143 from web-02
A=/root/answers.txt
W="index=main sourcetype=access_combined"
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u $AUTH --max-time 60 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
# The dashboard labelled SOC_Dashboard (Classic XML or Dashboard Studio), as one string
_dash() {
  curl -sk -u $AUTH -G "$API/servicesNS/-/-/data/ui/views" -d output_mode=json -d count=0 2>/dev/null \
    | jq -r '.entry[] | select(.content.label == "SOC_Dashboard" or .name == "SOC_Dashboard") | .content["eai:data"]' | tr -d "\n"
}
_viz() { _dash | grep -qiE "$1"; }
_report() { curl -sk -u $AUTH -G "$API/servicesNS/-/-/saved/searches/Top%20Clients" -d output_mode=json 2>/dev/null; }

for _ in $(seq 1 60); do [ "$(_spl "| tstats count where index=main")" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_spl "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. The numbers behind the panels (All time)"
check "SINGLE_503: access_combined events with status 503" '[ "$(_kv $A SINGLE_503)" = "$(_spl "search $W status=503 | stats count")" ]' "stats count gives one number"
check "PIE_SLICES: distinct client addresses among status 403" '[ "$(_kv $A PIE_SLICES)" = "$(_spl "search $W status=403 | stats dc(clientip)")" ]' "One slice per clientip"
check "TOP_NON200: the most common status code other than 200" '[ "$(_kv $A TOP_NON200)" = "$(_spl "search $W status!=200 | stats count by status | sort - count | head 1 | fields status")" ]' \
  "status!=200, then count by status"
check "POST_COUNT: requests with method POST" '[ "$(_kv $A POST_COUNT)" = "$(_spl "search $W method=POST | stats count")" ]' "count by method"
check "TOP_CLIENT_COUNT: requests from the busiest client" '[ "$(_kv $A TOP_CLIENT_COUNT)" = "$(_spl "search $W | stats count by clientip | sort - count | head 1 | fields count")" ]' \
  "top clientip, first row"
check "OUTAGE_HOST: the web server that returned the 503s" '[ "$(_kv $A OUTAGE_HOST)" = web-02 ]' "Split the trend by host"

section "2. The report"
check "A report named Top Clients exists and runs top clientip" '_report | jq -e ".entry[0].content.search | test(\"top +(limit=[0-9]+ +)?clientip\")" >/dev/null' \
  "Save As > Report, title Top Clients"
check "...and it is shared with the app, not private to admin" '_report | jq -e ".entry[0].acl.sharing == \"app\" or .entry[0].acl.sharing == \"global\"" >/dev/null' \
  "Settings > Searches, reports, and alerts > Edit Permissions"

section "3. SOC_Dashboard"
check "A dashboard titled SOC_Dashboard exists" '[ -n "$(_dash)" ]' "Dashboards > Create New Dashboard, title SOC_Dashboard"
check "...with a single value panel" '_viz "<single>|splunk\.singlevalue"' "Save As > Existing Dashboard from the Visualization tab"
check "...a pie chart" '_viz "charting\.chart\">pie<|splunk\.pie"' "Pie for a few categories"
check "...a bar chart" '_viz "charting\.chart\">bar<|splunk\.bar\""' "Bar: horizontal bars"
check "...a column chart" '_viz "charting\.chart\">column<|splunk\.column"' "Column: vertical bars"
check "...a line chart over time" '_viz "charting\.chart\">line<|splunk\.line" && _viz "timechart"' "timechart, as a line"
check "...and a panel that uses the Top Clients report itself" '_viz "ref=\"Top Clients\"|\"ref\": *\"Top Clients\""' \
  "Add Panel > New from Report, so the panel follows the report when it changes"
check "ALL_PANELS: you checked the dashboard shows all six" '[ "$(_kv $A ALL_PANELS | tr A-Z a-z)" = yes ] && _viz "<single>|splunk\.singlevalue" && _viz "ref=\"Top Clients\"|\"ref\": *\"Top Clients\""' \
  "Open it and look"
