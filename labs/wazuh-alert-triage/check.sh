# Checks for wazuh-alert-triage (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks the Wazuh indexer the same questions over its REST API.

IDX=https://wazuh.indexer:9200
DASH=https://wazuh.dashboard:5601
AUTH=admin:Lab-Wazuh-2026
A=/root/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
# _n QUERY: how many alerts match a query-string query ("*" = all)
_n() { curl -sk -u $AUTH --max-time 30 -G "$IDX/wazuh-alerts-*/_count" --data-urlencode "q=$1" 2>/dev/null | jq -r '.count // empty'; }
# _top FIELD QUERY: the most frequent value of FIELD among the matching alerts
_top() {
  curl -sk -u $AUTH --max-time 30 -H 'Content-Type: application/json' "$IDX/wazuh-alerts-*/_search" \
    -d "{\"size\":0,\"query\":{\"query_string\":{\"query\":\"$2\"}},\"aggs\":{\"t\":{\"terms\":{\"field\":\"$1\",\"size\":1}}}}" 2>/dev/null \
    | jq -r '.aggregations.t.buckets[0].key // empty'
}

# Wait for the feed to finish and the alert count to settle (a few minutes after the first ./lab up).
for _ in $(seq 1 90); do
  a=$(_n '*'); sleep 10; b=$(_n '*')
  [ -f /feed/done ] && [ -n "$a" ] && [ "$a" = "$b" ] && [ "${b:-0}" -gt 0 ] && break
done

section "0. Wazuh is ready"
check "The feed is done and the alert stream has settled" '[ -f /feed/done ] && [ "$(_n "*")" -gt 500 ]' \
  "The stack needs several minutes after ./lab up; run the check again later"

section "1. The whole stream"
check "TOTAL_ALERTS: alerts in wazuh-alerts-*" '[ "$(_kv $A TOTAL_ALERTS)" = "$(_n "*")" ]' \
  "Discover, no query, a time range that covers the whole lab session"

section "2. SSH: rule.id versus rule.groups"
check "TOP_INVALID_USER_SRC: top data.srcip among rule.id 5710" '[ "$(_kv $A TOP_INVALID_USER_SRC)" = "$(_top data.srcip "rule.id:5710")" ]' \
  "rule.id:5710, then the data.srcip field's top values"
check "TOP_AUTH_FAILED_SRC: top data.srcip among rule.groups authentication_failed" '[ "$(_kv $A TOP_AUTH_FAILED_SRC)" = "$(_top data.srcip "rule.groups:authentication_failed")" ]' \
  "rule.groups:authentication_failed is a wider net than one rule.id; compare rule.id values inside it"
check "TOP_SSH_USERNAME: top data.srcuser among rule.id 5710" '[ "$(_kv $A TOP_SSH_USERNAME)" = "$(_top data.srcuser "rule.id:5710")" ]' \
  "rule.id:5710, then data.srcuser"
check "BREACHED_ACCOUNT: the account a brute-forcing address then logged in as" '[ "$(_kv $A BREACHED_ACCOUNT)" = jenkins ]' \
  "rule.groups:authentication_success, and compare its data.srcip values with the failures"

section "3. File integrity"
check "FIM_MODIFIED: alerts for modified files (rule.id 550)" '[ "$(_kv $A FIM_MODIFIED)" = "$(_n "rule.id:550")" ]' "rule.id:550"
check "FIM_TOP_FILE: the file modified most often" '[ "$(_kv $A FIM_TOP_FILE)" = "$(_top syscheck.path "rule.id:550")" ]' "syscheck.path among rule.id:550"
check "NEW_FILE: the file that was added to the web root" '[ "$(_kv $A NEW_FILE)" = /srv/www/html/uploads/img-cache.php ]' \
  "rule.groups:syscheck, then look at the rule.id values that are not 550"

section "4. Web attacks"
check "SQLI_ALERTS: SQL injection alerts (rule.id 31103)" '[ "$(_kv $A SQLI_ALERTS)" = "$(_n "rule.id:31103")" ]' "rule.id:31103"
check "SQLI_SUCCESS_SRC: the source of the attack that returned 200" '[ "$(_kv $A SQLI_SUCCESS_SRC)" = "$(_top data.srcip "rule.id:31106")" ]' \
  "rule.groups:attack, then the rule.description values: which one says the attack worked?"

section "5. A saved search for the next shift"
check "Saved search ssh-invalid-users exists" \
  'curl -sk -u $AUTH -G "$DASH/api/saved_objects/_find" -d type=search -d search_fields=title --data-urlencode "search=\"ssh-invalid-users\"" | jq -e ".saved_objects[] | select(.attributes.title == \"ssh-invalid-users\")" >/dev/null' \
  "Discover > Save, title ssh-invalid-users"
check "...its query selects rule.id 5710" \
  'curl -sk -u $AUTH -G "$DASH/api/saved_objects/_find" -d type=search -d search_fields=title --data-urlencode "search=\"ssh-invalid-users\"" | jq -r ".saved_objects[] | select(.attributes.title == \"ssh-invalid-users\") | .attributes.kibanaSavedObjectMeta.searchSourceJSON" | grep -q "rule.id[^0-9]*5710"' \
  "The search bar query rule.id:5710 (DQL), saved with the search"
