# Checks for splunk-bruteforce-response (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk over its REST API; the SOAR log is local.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=1058
A=/root/answers.txt
SOAR=/var/log/soar/requests.jsonl
NAME="SSH Brute Force - Successful Authentication"
SEC="index=main sourcetype=linux_secure"
SRC='rex "from (?<src>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"'
USR='rex "for (?:invalid user )?(?<user>\S+) from"'
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u $AUTH --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
_ss() { curl -sk -u $AUTH -G "$API/servicesNS/-/-/saved/searches" -d output_mode=json -d count=0 --data-urlencode "search=name=\"$NAME\"" 2>/dev/null | jq -c --arg n "$NAME" '[.entry[] | select(.name == $n)][0] // empty'; }
_c() { _ss | jq -e ".content | $1" >/dev/null 2>&1; }
# Every address that failed and then got in, from outside the office network: what the SOAR should get
_breached() { _spl "search $SEC (\"Failed password\" OR \"Accepted password\") | $SRC | stats count(eval(searchmatch(\"Failed password\"))) AS f count(eval(searchmatch(\"Accepted password\"))) AS s by src | where f>0 AND s>0 AND NOT cidrmatch(\"10.0.0.0/8\", src) | sort src | fields src"; }
_got() { jq -r --arg n "$NAME" 'select(.body.search_name? == $n) | .body.result.src // empty' $SOAR 2>/dev/null | sort -u; }
_loud() { _spl "search $SEC \"Failed password\" | $SRC | stats count by src | where count>50 | fields src"; }

for _ in $(seq 1 60); do [ "$(_spl "| tstats count where index=main")" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_spl "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. The core questions"
check "ATTACKER: the source with more than 50 failed passwords" '[ -n "$(_loud)" ] && [ "$(_kv $A ATTACKER)" = "$(_loud)" ]' "rex the address, stats count by src, where count>50"
check "BURST: its failed passwords" '[ "$(_kv $A BURST)" = "$(_spl "search $SEC \"Failed password\" \"from $(_loud) \" | stats count")" ]' "The count on that row"
check "COMPROMISED: the account it then logged in as" '[ "$(_kv $A COMPROMISED)" = "$(_spl "search $SEC \"Accepted password\" \"from $(_loud) \" | rex \"for (?<u>\S+) from\" | stats count by u | fields u")" ]' \
  "Accepted password from that address"
check "SUCCESSES: its successful password logins" '[ "$(_kv $A SUCCESSES)" = "$(_spl "search $SEC \"Accepted password\" \"from $(_loud) \" | stats count")" ]' "Look at the whole time range"
check "MOST_TARGETED: the username with the most failed passwords" '[ "$(_kv $A MOST_TARGETED)" = "$(_spl "search $SEC \"Failed password\" | $USR | stats count by user | sort - count | head 1 | fields user")" ]' \
  "Mind the invalid user lines: anchor the rex"

section "2. What fails>50 misses"
check "SLOW_BREACH: the other address that failed more than 10 times and got in" '[ "$(_kv $A SLOW_BREACH)" = 203.0.113.88 ]' "Lower the threshold to 10, keep successes>0"
check "SPRAY_USER: the account sprayed from many addresses, a few guesses each, and breached" '[ "$(_kv $A SPRAY_USER)" = backup ]' \
  "stats by user: dc(src), max guesses per source, and successes"
check "SPRAY_SOURCES: distinct addresses that failed against it" '[ "$(_kv $A SPRAY_SOURCES)" = "$(_spl "search $SEC \"Failed password for backup \" | $SRC | stats dc(src)")" ]' "dc(src)"
check "SPRAY_WINNER: the address that got into it" '[ "$(_kv $A SPRAY_WINNER)" = 192.0.2.137 ]' "Accepted password for that account"
check "FALSE_POSITIVES: office addresses that failed and then got in" '[ "$(_kv $A FALSE_POSITIVES)" = "$(_spl "search $SEC (\"Failed password\" OR \"Accepted password\") | $SRC | where cidrmatch(\"10.0.0.0/8\", src) | stats count(eval(searchmatch(\"Failed password\"))) AS f count(eval(searchmatch(\"Accepted password\"))) AS s by src | where f>0 AND s>0 | stats count")" ]' \
  "The office network is 10.0.0.0/8: staff typos"

section "3. The response alert"
check "An alert named SSH Brute Force - Successful Authentication runs every 15 minutes over All time" '_c ".is_scheduled == true and (.cron_schedule | gsub(\" +\"; \" \")) == \"*/15 * * * *\" and ((.[\"dispatch.earliest_time\"] // \"\") | . == \"\" or . == \"0\")"' \
  "Save As > Alert, Run on Cron Schedule; the data is from October, so All time"
check "...its search returns exactly the breaching addresses outside 10.0.0.0/8" '_q=$(_ss | jq -r .content.search); [ -n "$_q" ] && [ -n "$(_breached)" ] && [ "$(_spl "search $(echo "$_q" | sed "s/^ *search //") | sort src | fields src")" = "$(_breached)" ]' \
  "Failures and successes by src, both above 0, and NOT cidrmatch for the office network"
check "...triggers for each result, throttled on src for 1 hour" '_c ".alert_type == \"number of events\" and .alert_comparator == \"greater than\" and .alert_threshold == \"0\" and .[\"alert.digest_mode\"] == false and .[\"alert.suppress\"] == true and (.[\"alert.suppress.fields\"] | gsub(\" \"; \"\")) == \"src\" and .[\"alert.suppress.period\"] == \"1h\""' \
  "Number of Results > 0, For each result, Throttle on src for 1 hour"
check "...adds to Triggered Alerts and posts to the SOAR" '_c ".[\"alert.track\"] == true and (.actions | split(\",\") | map(gsub(\" \"; \"\")) | index(\"webhook\")) and .[\"action.webhook.param.url\"] == \"http://soar:8088/ban\""' \
  "Two trigger actions; the URL exactly http://soar:8088/ban"
check "The SOAR received every breaching address, and no office address" '[ -n "$(_breached)" ] && [ "$(_got)" = "$(_breached)" ]' \
  "The first run is at the next quarter hour; tail /var/log/soar/requests.jsonl"
check "BANNED: addresses the SOAR received" '[ -n "$(_got)" ] && [ "$(_kv $A BANNED)" = "$(_got | wc -l | tr -d " ")" ]' "jq .body.result.src, sort -u"
