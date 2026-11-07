# Checks for wazuh-web-attack-triage (see templates/lab/check.sh for the rules).

O=/var/ossec
AL=$O/logs/alerts/alerts.json
A=/root/answers.txt
LOGF=/var/log/lab/web-server-01-access.log
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
# _sel JQ-FILTER: web-server-01 alerts that match
_sel() { jq -c "select(.location == \"$LOGF\") | select($1)" $AL 2>/dev/null; }
_n() { _sel "$1" | wc -l | tr -d " "; }
_tech='(.rule.id == "31103" or .rule.id == "31104" or .rule.id == "31105")'
_top() { _sel "$1" | jq -r '.data.srcip' | sort | uniq -c | sort -k1,1rn -k2 | awk 'NR == 1 {print $2}'; }
_has() { grep -qE "<rule[^>]*id=\"100330\"" $O/etc/rules/*.xml 2>/dev/null; }
# _rule URL STATUS: the rule an access-log line for URL ends in, through wazuh-logtest (stderr)
_rule() { printf '203.0.113.250 - - [04/Nov/2026:11:00:00 +0000] "GET %s HTTP/1.1" %s 512 "-" "curl/8.5.0"\n' "$1" "$2" \
  | $O/bin/wazuh-logtest 2>&1 | sed -n '/Phase 3/,$p' | grep -E "^[[:space:]]+id: '" | head -n1 | cut -d"'" -f2; }

for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done

section "0. Wazuh is ready"
check "The manager is up and web-server-01's morning has been analysed" '[ -f /var/lib/lab-feed-done ] && [ "$(_n "true")" -gt 50 ]' \
  "The manager needs a minute or two after ./lab up; run the check again"

section "1. The core questions"
check "SQLI_31103: SQL injection alerts (rule 31103)" '[ "$(_kv $A SQLI_31103)" = "$(_n ".rule.id == \"31103\"")" ]' "jq select on .rule.id, then count lines"
check "XSS_31105: cross-site scripting alerts (rule 31105)" '[ "$(_kv $A XSS_31105)" = "$(_n ".rule.id == \"31105\"")" ]' "The same, another rule id"
check "TRAVERSAL_31104: directory traversal alerts (rule 31104)" '[ "$(_kv $A TRAVERSAL_31104)" = "$(_n ".rule.id == \"31104\"")" ]' "The stock rule calls it Common web attack"
check "TOP_ATTACKER: the source IP with the most alerts across the three techniques" '[ "$(_kv $A TOP_ATTACKER)" = "$(_top "$_tech")" ]' \
  "All three rule ids in one select, then rank .data.srcip"
check "TOP_ATTACKER_COUNT: its alerts across the three techniques" '[ "$(_kv $A TOP_ATTACKER_COUNT)" = "$(_n "$_tech and .data.srcip == \"$(_top "$_tech")\"")" ]' \
  "Is it first in any single technique?"

section "2. What the technique counts do not show"
check "SUCCESS_RULE: the rule an attack that got a 200 ends in" '[ "$(_kv $A SUCCESS_RULE)" = 31106 ]' "List every rule.id, not only the three"
check "SUCCESS_IP: the source of the attack that worked" '[ "$(_kv $A SUCCESS_IP)" = "$(_sel ".rule.id == \"31106\"" | jq -r .data.srcip | head -n1)" ]' \
  "Its two earlier tries were blocked"
check "GROUP_TOP: the IP that rule.groups attack ranks first" '[ "$(_kv $A GROUP_TOP)" = "$(_top ".rule.groups | index(\"attack\")")" ]' \
  "Which rule ids does that IP have?"
check "ENCODED_400: traversal attempts filed only as plain 400 errors" '[ "$(_kv $A ENCODED_400)" = "$(_n ".rule.id == \"31101\" and (.data.url | test(\"%2f|%5c\"; \"i\")) and (.data.url | test(\"[.]{2}|%2e%2e\"; \"i\"))")" ]' \
  "31101 alerts whose URL climbs directories with encoded slashes"
check "LEAKED_FILE: the file an encoded traversal fetched with status 200" '[ "$(_kv $A LEAKED_FILE)" = /etc/nginx/conf.d/shop.conf ]' \
  "No alert has it: read the raw access log, and decode the path"

section "3. A rule for encoded traversal (100330)"
check "Rule 100330 (level 10) exists and the manager loads it" '_has && grep -qE "<rule[^>]*id=\"100330\"[^>]*level=\"10\"|<rule[^>]*level=\"10\"[^>]*id=\"100330\"" $O/etc/rules/*.xml && $O/bin/wazuh-analysisd -t >/dev/null 2>&1' \
  "id and level on the rule tag; validate with wazuh-analysisd -t, then restart"
check "An encoded traversal that got 404 raises rule 100330" '_has && [ "$(_rule "/download.php?file=..%2F..%2Fetc%2Fpasswd" 404)" = 100330 ] && [ "$(_rule "/get?f=%2e%2e%2f%2e%2e%2fetc%2fshadow" 403)" = 100330 ]' \
  "A child of the parents a 4xx request can reach; match the URL case-insensitively"
check "...and one that got 200 too" '_has && [ "$(_rule "/download.php?file=..%2F..%2Fetc%2Fhosts" 200)" = 100330 ] && [ "$(_rule "/get?f=..%5C..%5Cweb.config" 200)" = 100330 ]' \
  "A 200 never reaches 31101: which rules does it pass through?"
check "...but plain traversal, SQL injection and normal requests keep their rules" '_has && [ "$(_rule "/download.php?file=..%2F..%2Fetc%2Fpasswd" 404)" = 100330 ] && [ "$(_rule "/download.php?file=../../../etc/passwd" 404)" = 31104 ] && [ "$(_rule "/product.php?id=1%20union%20select%201" 403)" = 31103 ] && [ "$(_rule "/download.php?file=catalog-2026.pdf" 200)" != 100330 ] && [ "$(_rule "/search.php?q=a%2Fb" 200)" != 100330 ]' \
  "An encoded slash alone is not traversal: require the dots before it"
