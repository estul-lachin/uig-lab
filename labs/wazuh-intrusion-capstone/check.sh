# Checks for wazuh-intrusion-capstone (see templates/lab/check.sh for the rules).

O=/var/ossec
AL=$O/logs/alerts/alerts.json
A=/root/answers.txt
WEB=/var/log/lab/nginx-access.log
SSH=/var/log/lab/secure.log
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
# _sel JQ-FILTER: the morning's web, SSH and FIM alerts that match
_sel() { jq -c "select(.location == \"$WEB\" or .location == \"$SSH\" or .location == \"syscheck\") | select($1)" $AL 2>/dev/null; }
_n() { _sel "$1" | wc -l | tr -d " "; }
_ips() { _sel ".rule.id == \"$1\"" | jq -r '.data.srcip' | sort -u; }
_attacker() { comm -12 <(_ips 31103) <(_ips 5710) | comm -12 - <(_ips 5715) | head -n1; }
_has() { grep -qE "<rule[^>]*id=\"100350\"" $O/etc/rules/*.xml 2>/dev/null; }
# _last LINE...: feed sshd lines into one wazuh-logtest session, print the rule the last one ends in
_last() {
  for l in "$@"; do printf 'Nov  4 11:00:00 web-server-01 sshd[777]: %s\n' "$l"; done \
    | $O/bin/wazuh-logtest 2>&1 | awk '/Phase 3/ {p = 1; id = ""} p && /^[[:space:]]+id: / && id == "" {id = $2} /full event/ {p = 0} END {gsub("'"'"'", "", id); print id}'
}
_try() { _last "Invalid user $2 from $1 port 40001" "Connection closed by invalid user $2 $1 port 40001 [preauth]" "Accepted password for $3 from $4 port 40002 ssh2"; }

for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done

section "0. Wazuh is ready"
check "The manager is up and web-server-01's morning has been analysed" '[ -f /var/lib/lab-feed-done ] && [ "$(_n "true")" -gt 100 ] && [ -n "$(_attacker)" ]' \
  "The manager needs a minute or two after ./lab up; run the check again"

section "1. The course questions"
check "ATTACKER_IP: the address in 31103, 5710 and 5715 alike" '[ "$(_kv $A ATTACKER_IP)" = "$(_attacker)" ]' "One sorted list of data.srcip per rule, then the common line"
check "RECON_31103: its SQL injection alerts" '[ "$(_kv $A RECON_31103)" = "$(_n ".rule.id == \"31103\" and .data.srcip == \"$(_attacker)\"")" ]' "Both conditions in one select"
check "BRUTE_5710: its rule-5710 alerts" '[ "$(_kv $A BRUTE_5710)" = "$(_n ".rule.id == \"5710\" and .data.srcip == \"$(_attacker)\"")" ]' "The same, for 5710"
check "BREACHED_ACCOUNT: the account it logged in as" '[ "$(_kv $A BREACHED_ACCOUNT)" = "$(_sel ".rule.id == \"5715\" and .data.srcip == \"$(_attacker)\"" | jq -r .data.dstuser | head -n1)" ]' \
  "In Wazuh the account of an sshd login is data.dstuser"
check "PERSISTENCE_FILE: the systemd unit it dropped" '[ "$(_kv $A PERSISTENCE_FILE)" = /etc/systemd/system/dbus-update.service ] && [ "$(_n ".rule.id == \"554\" and .syscheck.path == \"/etc/systemd/system/dbus-update.service\"")" = 1 ]' \
  "rule.id 554, .syscheck.path; one of them was there before the login"
check "NOISE_5710: rule-5710 alerts from every source" '[ "$(_kv $A NOISE_5710)" = "$(_n ".rule.id == \"5710\"")" ]' "rule.id 5710 alone"

section "2. The rest of the story"
check "LEAK_RULE: the rule of the attacker web request that worked" '[ "$(_kv $A LEAK_RULE)" = 31106 ] && [ "$(_n ".rule.id == \"31106\" and .data.srcip == \"$(_attacker)\"")" -ge 1 ]' \
  "List every rule.id for that address; one web request got a 200"
check "LEAK_TABLE: the database table that request read" '[ "$(_kv $A LEAK_TABLE)" = users ]' "Read its .data.url"
check "STORM_RULE: the frequency rule the noisy brute force triggered" '_f=$(_sel "(.rule.groups | index(\"authentication_failures\")) and .data.srcip != \"$(_attacker)\"" | jq -r .rule.id | head -n1); [ -n "$_f" ] && [ "$(_kv $A STORM_RULE)" = "$_f" ] && [ "$(_n "(.rule.groups | index(\"authentication_failures\")) and .data.srcip == \"$(_attacker)\"")" = 0 ]' \
  "rule.groups authentication_failures; the attacker has none. How many guesses does it take?"
check "PERSIST_RUNS: the program the unit starts" '[ "$(_kv $A PERSIST_RUNS)" = /usr/local/sbin/dbus-update ]' "Read the unit file on disk: ExecStart"
check "C2_PORT: the port that program connects back to" '[ "$(_kv $A C2_PORT)" = 8443 ]' "Read the program; /dev/tcp/host/port"

section "3. A rule for the low-and-slow login (100350)"
check "Rule 100350 (level 12) exists and the manager loads it" '_has && grep -qE "<rule[^>]*id=\"100350\"[^>]*level=\"12\"|<rule[^>]*level=\"12\"[^>]*id=\"100350\"" $O/etc/rules/*.xml && $O/bin/wazuh-analysisd -t >/dev/null 2>&1' \
  "id and level on the rule tag; validate with wazuh-analysisd -t, then restart"
check "A login after a single invalid-user attempt from the same address raises 100350" '_has && [ "$(_try 203.0.113.200 oracle webadmin 203.0.113.200)" = 100350 ]' \
  "A child of 5715 that needs an earlier 5710 from the same srcip (if_matched_sid, same_srcip, timeframe)"
check "...but not a login from another address" '_has && [ "$(_try 203.0.113.200 oracle webadmin 203.0.113.200)" = 100350 ] && [ "$(_try 203.0.113.201 oracle webadmin 198.51.100.202)" = 5715 ]' \
  "The failure and the success must share the source address"
check "...nor a login with no failure before it" '_has && [ "$(_try 203.0.113.200 oracle webadmin 203.0.113.200)" = 100350 ] && [ "$(_last "Accepted publickey for mira from 10.20.0.21 port 40002 ssh2")" = 5715 ]' \
  "Without a matched 5710 the parent rule stays"
