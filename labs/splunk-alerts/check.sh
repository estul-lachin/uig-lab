# Checks for splunk-alerts (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk over its REST API; the WAF log is local.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=5286
A=/root/answers.txt
WAF=/var/log/waf/requests.jsonl
SSH_ALERT="SSH Brute Force"
ERR_ALERT="Server Error"
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
# _kvs KEY: the answer with runs of spaces squeezed (for cron expressions)
_kvs() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -s " \t" " " | sed -e "s/^ //" -e "s/ \$//"; }
_lc() { _kv $A "$1" | tr "[:upper:]" "[:lower:]"; }
_spl() { curl -sk -u $AUTH --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
_ss() { curl -sk -u $AUTH -G "$API/servicesNS/-/-/saved/searches" -d output_mode=json -d count=0 --data-urlencode "search=name=\"$1\"" 2>/dev/null | jq -c --arg n "$1" '[.entry[] | select(.name == $n)][0] // empty'; }
# _c ALERT JQ-EXPR: true when the expression holds on the alert's .content
_c() { _ss "$1" | jq -e ".content | $2" >/dev/null 2>&1; }
_attackers() { _spl 'search index=main sourcetype=linux_secure "Failed password" | rex "from (?<src>\S+)" | stats count by src | where count>10 | sort src | fields src'; }
_got() { jq -r --arg n "$SSH_ALERT" 'select(.body.search_name? == $n) | .body.result.src // empty' $WAF 2>/dev/null | sort -u; }
_suppressed() { _spl "search index=_internal sourcetype=scheduler savedsearch_name=\"$SSH_ALERT\" suppressed>0 | stats max(suppressed)"; }

for _ in $(seq 1 60); do [ "$(_spl "| tstats count where index=main")" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_spl "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. The course questions"
check "CRON_2MIN: the cron expression for every 2 minutes" '[ "$(_kvs CRON_2MIN)" = "*/2 * * * *" ]' "Five fields: minute hour day month weekday"
check "ALERT_TYPE: the alert type that runs on a fixed interval" '[ "$(_lc ALERT_TYPE)" = scheduled ]' "One word"
check "TRIGGER: one action for every matching event" '[ "$(_lc TRIGGER)" = per-result ]' "Number of Results or Per-Result"
check "THROTTLE_FIELD: the field to suppress Server Error alerts on" '[ "$(_kv $A THROTTLE_FIELD)" = uri_path ]' "One alert per broken endpoint"
check "ERROR_EVENTS: events with status 500 or above, All time" '[ "$(_kv $A ERROR_EVENTS)" = "$(_spl "search index=main sourcetype=access_combined status>=500 | stats count")" ]' \
  "status>=500 | stats count"

section "2. The SSH Brute Force alert"
check "A saved alert named SSH Brute Force runs on cron */2 * * * * over All time" '_c "$SSH_ALERT" ".is_scheduled == true and (.cron_schedule | gsub(\" +\"; \" \")) == \"*/2 * * * *\" and ((.[\"dispatch.earliest_time\"] // \"\") | . == \"\" or . == \"0\")"' \
  "Save As > Alert, Scheduled, Run on Cron Schedule; the shop data is from the past, so the time range must be All time"
check "...its search finds the brute-forcing sources" '_q=$(_ss "$SSH_ALERT" | jq -r .content.search); [ -n "$_q" ] && [ "$(_spl "search $(echo "$_q" | sed "s/^ *search //") | sort src | fields src")" = "$(_attackers)" ]' \
  "The rex for src, stats count by src, where count>10"
check "...triggers when there is at least one result, once for each result" '_c "$SSH_ALERT" ".alert_type == \"number of events\" and .alert_comparator == \"greater than\" and .alert_threshold == \"0\" and .[\"alert.digest_mode\"] == false"' \
  "Number of Results is greater than 0; Trigger: For each result"
check "...throttles on src" '_c "$SSH_ALERT" ".[\"alert.suppress\"] == true and (.[\"alert.suppress.fields\"] | gsub(\" \"; \"\")) == \"src\""' "Throttle, Suppress results containing field value: src"
check "...adds to Triggered Alerts with severity Medium" '_c "$SSH_ALERT" ".[\"alert.track\"] == true and .[\"alert.severity\"] == 3"' "Trigger action Add to Triggered Alerts"
check "...and posts to the WAF webhook" '_c "$SSH_ALERT" "(.actions | split(\",\") | map(gsub(\" \"; \"\")) | index(\"webhook\")) and .[\"action.webhook.param.url\"] == \"http://waf:8088/ban\""' \
  "Trigger action Webhook, URL http://waf:8088/ban (exactly)"
check "The WAF received every brute-forcing source from that alert" '[ -n "$(_attackers)" ] && [ "$(_got)" = "$(_attackers)" ]' \
  "Wait for the next even minute after saving; tail /var/log/waf/requests.jsonl"
check "A later scheduled run was throttled" '_s=$(_suppressed); [ -n "$_s" ] && [ "$_s" -gt 0 ]' \
  "Throttling shows from the second scheduled run on: give it 4 minutes"

section "3. The Server Error alert"
check "A saved alert named Server Error runs in real time on status 500 and above" '_c "$ERR_ALERT" ".[\"dispatch.earliest_time\"] | startswith(\"rt\")" && _ss "$ERR_ALERT" | jq -r .content.search | grep -qE "status *>= *500"' \
  "Save As > Alert, Real-time; status>=500 in the search"
check "...triggers per result, throttled on uri_path for 10 minutes" '_c "$ERR_ALERT" ".alert_type == \"always\" and .[\"alert.digest_mode\"] == false and .[\"alert.suppress\"] == true and (.[\"alert.suppress.fields\"] | gsub(\" \"; \"\")) == \"uri_path\" and .[\"alert.suppress.period\"] == \"10m\""' \
  "Trigger: Per-Result; edit the alert afterwards for the throttle"
check "...and adds to Triggered Alerts with severity High" '_c "$ERR_ALERT" ".[\"alert.track\"] == true and .[\"alert.severity\"] == 4"' "Add to Triggered Alerts, High"

section "4. What the alerts really did"
check "BANNED_IPS: distinct addresses the WAF received" '[ -n "$(_got)" ] && [ "$(_kv $A BANNED_IPS)" = "$(_got | wc -l | tr -d " ")" ]' "jq on the WAF log, .body.result.src"
check "RUN_SUPPRESSED: results a throttled scheduled run suppressed" '[ -n "$(_suppressed)" ] && [ "$(_kv $A RUN_SUPPRESSED)" = "$(_suppressed)" ]' \
  "index=_internal sourcetype=scheduler, the suppressed field"
check "RT_TRIGGERED: times the real-time Server Error alert has fired" '[ "$(_kv $A RT_TRIGGERED)" = 0 ] && _ss "$ERR_ALERT" | grep -q .' \
  "Activity > Triggered Alerts. What does a real-time search look at?"
check "ENDPOINTS_MAX: the most actions Server Error could take in 10 minutes for those events" '[ "$(_kv $A ENDPOINTS_MAX)" = "$(_spl "search index=main sourcetype=access_combined status>=500 | stats dc(uri_path)")" ]' \
  "One action per distinct value of the throttle field"
check "CRON_BUSINESS: every 15 minutes, 08:00 to 17:59, Monday to Friday" '[ "$(_kvs CRON_BUSINESS)" = "*/15 8-17 * * 1-5" ]' "Ranges with a dash; Monday is 1"
