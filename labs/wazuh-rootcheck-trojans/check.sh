# Checks for wazuh-rootcheck-trojans (see templates/lab/check.sh for the rules).

O=/var/ossec
AL=$O/logs/alerts/alerts.json
A=/root/answers.txt
MARK=/var/lib/lab-feed-done
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
# _win JQ-FILTER: the fleet's rootcheck alerts (before the marker time) that match
_win() { jq -c --argjson end "$(cat $MARK 2>/dev/null || echo 0)" \
  "select(.location == \"rootcheck\") | select((.timestamp[0:19] + \"Z\" | fromdate) <= \$end) | select($1)" $AL 2>/dev/null; }
_n() { _win "$1" | wc -l | tr -d " "; }
# _rank N: the host in place N by rule-510 count
_rank() { _win '.rule.id == "510"' | jq -r '.agent.name' | sort | uniq -c | sort -k1,1rn -k2 | awk -v n="$1" 'NR == n {print $2}'; }
_trojan() { _win ".agent.name == \"$1\" and .data.title == \"Trojaned version of file detected.\"" | jq -r '.data.file' | head -n1; }
_has() { grep -qE "<rule[^>]*id=\"100320\"" $O/etc/rules/*.xml 2>/dev/null; }
# _probe MESSAGE: hand one rootcheck message from a probe host to analysisd, print the rule it ends in
_probe() {
  _h="check-probe-$$-$RANDOM"; _f=$(mktemp)
  printf '%s|10.20.0.250|%s\n' "$_h" "$1" > "$_f"
  $O/framework/python/bin/python3 -I /opt/lab/inject.py "$_f" >/dev/null 2>&1; rm -f "$_f"
  for _ in $(seq 1 10); do
    _r=$(jq -r --arg h "$_h" 'select(.agent.name == $h) | .rule.id' $AL 2>/dev/null | head -n1)
    [ -n "$_r" ] && break; sleep 1
  done
  echo "$_r"
}
_tro() { _probe "Trojaned version of file '/usr/bin/$1' detected. Signature used: 'bash|file\\.h' (Generic)."; }

for _ in $(seq 1 60); do [ -f $MARK ] && break; sleep 5; done
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done

section "0. Wazuh is ready"
check "The manager is up and the fleet's rootcheck results have been analysed" '[ -f $MARK ] && [ "$(_n "true")" -ge 25 ]' \
  "The manager needs a minute or two after ./lab up; run the check again"

section "1. The core questions"
check "RC_TOTAL: rootcheck detections (rule 510), all hosts" '[ "$(_kv $A RC_TOTAL)" = "$(_n ".rule.id == \"510\"")" ]' "jq select on .rule.id, then count lines"
check "WORST_HOST: the host with the most of them" '[ "$(_kv $A WORST_HOST)" = "$(_rank 1)" ]' ".agent.name | sort | uniq -c | sort -rn"
check "WORST_COUNT: rule-510 detections on that host" '[ "$(_kv $A WORST_COUNT)" = "$(_n ".rule.id == \"510\" and .agent.name == \"$(_rank 1)\"")" ]' "Both conditions in one select"
check "TROJAN_FILE: the trojaned binary on that host" '[ -n "$(_trojan "$(_rank 1)")" ] && [ "$(_kv $A TROJAN_FILE)" = "$(_trojan "$(_rank 1)")" ]' \
  ".data.title and .data.file; the full path"
check "SECOND_HOST: the host in second place" '[ "$(_kv $A SECOND_HOST)" = "$(_rank 2)" ]' "The second line of the same ranking"

section "2. What the 510 count does not show"
check "KERNEL_RULE: the rule hidden processes get instead of 510" '[ "$(_kv $A KERNEL_RULE)" = 521 ]' \
  "List every rule.id with location rootcheck, not only 510"
check "WORST_ALL: every rootcheck alert on the worst host" '[ "$(_kv $A WORST_ALL)" = "$(_n ".agent.name == \"$(_rank 1)\"")" ]' \
  "510 plus its children; rule.groups contains rootcheck"
check "TROJAN_HOSTS: hosts with at least one trojaned binary" '[ "$(_kv $A TROJAN_HOSTS)" = "$(_win ".data.title == \"Trojaned version of file detected.\"" | jq -r .agent.name | sort -u | wc -l | tr -d " ")" ]' \
  "Group by host on .data.title, not on the count"
check "QUIET_TROJAN_HOST: the infected host near the bottom of the ranking" '[ "$(_kv $A QUIET_TROJAN_HOST)" = bastion-01 ]' \
  "Infected, but with only a couple of detections"
check "QUIET_TROJAN_FILE: its trojaned binary" '[ "$(_kv $A QUIET_TROJAN_FILE)" = "$(_trojan bastion-01)" ]' "Full path"

section "3. A rule for trojaned binaries (100320)"
check "Rule 100320 (level 12) exists and the manager loads it" '_has && grep -qE "<rule[^>]*id=\"100320\"[^>]*level=\"12\"|<rule[^>]*level=\"12\"[^>]*id=\"100320\"" $O/etc/rules/*.xml && $O/bin/wazuh-analysisd -t >/dev/null 2>&1' \
  "id and level on the rule tag; validate with wazuh-analysisd -t, then restart"
check "A trojaned binary on a new host raises rule 100320" '_has && [ "$(_tro passwd)" = 100320 ] && [ "$(_tro chsh)" = 100320 ]' \
  "A child of 510 with a match on the start of the message; restart the manager"
check "...but other rootcheck findings stay 510" '_has && [ "$(_tro su)" = 100320 ] && [ "$(_probe "File '"'"'/dev/shm/probe.lock'"'"' present on /dev. Possible hidden file.")" = 510 ] && [ "$(_probe "Interface '"'"'eth1'"'"' in promiscuous mode.")" = 510 ] && [ "$(_probe "Port '"'"'6666'"'"'(tcp) hidden. Kernel-level rootkit or trojaned version of netstat.")" = 510 ]' \
  "Match the trojan message, not any word"
check "...and hidden processes stay 521" '_has && [ "$(_tro su)" = 100320 ] && [ "$(_probe "Process '"'"'777'"'"' hidden from /proc. Possible kernel level rootkit.")" = 521 ]' \
  "Your rule must not take over the kernel-rootkit rule"
