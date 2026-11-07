# Checks for wazuh-ssh-bruteforce (see templates/lab/check.sh for the rules).

O=/var/ossec
AL=$O/logs/alerts/alerts.json
A=/root/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
# _sel JQ-FILTER: bastion-01 alerts that match
_sel() { jq -c "select(.location == \"/var/log/lab/bastion-01.log\") | select($1)" $AL 2>/dev/null; }
_n() { _sel "$1" | wc -l | tr -d " "; }
_top() { _sel '.rule.id == "5710"' | jq -r '.data.srcip' | sort | uniq -c | sort -k1,1rn -k2 | awk 'NR == 1 {print $2}'; }
_has() { grep -qE "<rule[^>]*id=\"100340\"" $O/etc/rules/*.xml 2>/dev/null; }
# _rule LINE: the rule an sshd line ends in, through wazuh-logtest (which writes to stderr)
_rule() { printf 'Nov  4 11:00:00 bastion-01 sshd[31337]: %s\n' "$1" | $O/bin/wazuh-logtest 2>&1 | sed -n '/Phase 3/,$p' | grep -E "^[[:space:]]+id: '" | head -n1 | cut -d"'" -f2; }
_acc() { _rule "Accepted $3 for $1 from $2 port 50022 ssh2"; }

for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done

section "0. Wazuh is ready"
check "The manager is up and bastion-01's morning has been analysed" '[ -f /var/lib/lab-feed-done ] && [ "$(_n "true")" -gt 100 ]' \
  "The manager needs a minute or two after ./lab up; run the check again"

section "1. The core questions"
check "FAILED_5710: rule-5710 alerts" '[ "$(_kv $A FAILED_5710)" = "$(_n ".rule.id == \"5710\"")" ]' "jq select on .rule.id, then count lines"
check "TOP_SRC: the source IP with the most of them" '[ "$(_kv $A TOP_SRC)" = "$(_top)" ]' ".data.srcip | sort | uniq -c | sort -rn"
check "TOP_SRC_5710: how many of them are that address" '[ "$(_kv $A TOP_SRC_5710)" = "$(_n ".rule.id == \"5710\" and .data.srcip == \"$(_top)\"")" ]' "Both conditions in one select"
check "COMPROMISED: the account that address logged in as" '[ "$(_kv $A COMPROMISED)" = deploy ]' \
  "Look for authentication_success in rule.groups, or for Accepted in full_log, from that address"
check "SUCCESS_5715: rule-5715 alerts in total" '[ "$(_kv $A SUCCESS_5715)" = "$(_n ".rule.id == \"5715\"")" ]' "rule.id 5715 only"

section "2. Going further"
check "BREACH_RULE: the rule the attacker's login got instead of 5715" '_b=$(_sel ".data.srcip == \"$(_top)\" and (.full_log | test(\"Accepted \"))" | jq -r .rule.id | head -n1); [ "$(_kv $A BREACH_RULE)" = "$_b" ]' \
  "List every rule.id for that address, not only 5710 and 5715"
check "DISTINCT_USERS: different non-existent usernames the attacker tried" '[ "$(_kv $A DISTINCT_USERS)" = "$(_sel ".rule.id == \"5710\" and .data.srcip == \"$(_top)\"" | jq -r .data.srcuser | sort -u | wc -l | tr -d " ")" ]' \
  "Each guess writes two log lines, so 5710 counts lines, not guesses"
check "DEPLOY_GUESSES: wrong passwords for the real account, from the attacker" '[ "$(_kv $A DEPLOY_GUESSES)" = "$(_n ".data.srcip == \"$(_top)\" and (.full_log | test(\"Failed password for deploy \"))")" ]' \
  "Not in 5710 at all: an existing user gets another rule, and one alert went to a frequency rule"
check "REUSE_IP: the second address that logged in as that account" '[ "$(_kv $A REUSE_IP)" = 198.51.100.230 ]' \
  "No failures before it, and it is not one of the staff addresses"

section "3. A rule for external logins (100340)"
check "Rule 100340 (level 12) exists and the manager loads it" '_has && grep -qE "<rule[^>]*id=\"100340\"[^>]*level=\"12\"|<rule[^>]*level=\"12\"[^>]*id=\"100340\"" $O/etc/rules/*.xml && $O/bin/wazuh-analysisd -t >/dev/null 2>&1' \
  "id and level on the rule tag; validate with wazuh-analysisd -t, then restart"
check "A login from an internet address raises rule 100340" '_has && [ "$(_acc deploy 198.51.100.7 password)" = 100340 ] && [ "$(_acc mira 203.0.113.9 publickey)" = 100340 ]' \
  "A child of 5715 with a srcip condition; restart the manager"
check "...but staff logins from 10.0.0.0/8 stay 5715" '_has && [ "$(_acc deploy 198.51.100.7 password)" = 100340 ] && [ "$(_acc mira 10.20.0.21 publickey)" = 5715 ] && [ "$(_acc ops 10.200.3.4 publickey)" = 5715 ]' \
  "Negate a whole network: srcip takes a CIDR and a negate attribute"
check "...and failed logins never raise it" '_has && [ "$(_acc deploy 198.51.100.7 password)" = 100340 ] && [ "$(_rule "Failed password for deploy from 198.51.100.7 port 50022 ssh2")" = 5760 ]' \
  "Only successes are children of 5715"
