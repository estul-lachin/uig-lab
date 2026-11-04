# Checks for wazuh-sudo-abuse (see templates/lab/check.sh for the rules).

O=/var/ossec
AL=$O/logs/alerts/alerts.json
A=/root/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
# _n JQ-FILTER: how many alerts from web-server-01 match
_n() { jq -c "select(.location == \"/var/log/lab/web-server-01.log\") | select($1)" $AL 2>/dev/null | wc -l; }
_top_failer() { jq -r 'select(.rule.id == "5401") | .data.srcuser' $AL 2>/dev/null | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}'; }
# _rule LINE: the rule a sudo line ends in, through wazuh-logtest (which writes to stderr)
_rule() { printf '%s\n' "$1" | $O/bin/wazuh-logtest 2>&1 | grep -E "^[[:space:]]+id: '" | tail -n1 | cut -d"'" -f2; }
_line() { printf 'Nov  3 15:00:00 web-server-01 sudo: %8s : TTY=pts/1 ; PWD=/home/%s ; USER=%s ; COMMAND=%s' "$1" "$1" "$2" "$3"; }
_has() { grep -qE "<rule[^>]*id=\"100300\"" $O/etc/rules/*.xml 2>/dev/null; }

for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done

section "0. Wazuh is ready"
check "The manager is up and web-server-01's afternoon has been analysed" '[ -f /var/lib/lab-feed-done ] && [ "$(_n "true")" -gt 80 ]' \
  "The manager needs a minute or two after ./lab up; run the check again"

section "1. The course questions"
check "FAILED_5401: failed sudo attempts (rule 5401)" '[ "$(_kv $A FAILED_5401)" = "$(_n ".rule.id == \"5401\"")" ]' "jq select(.rule.id == \"5401\"), then count"
check "TOP_FAILER: the user with the most of them" '[ "$(_kv $A TOP_FAILER)" = "$(_top_failer)" ]' ".data.srcuser | sort | uniq -c"
check "FAILER_5401: how many of them that user had" '[ "$(_kv $A FAILER_5401)" = "$(_n ".rule.id == \"5401\" and .data.srcuser == \"$(_top_failer)\"")" ]' "Both conditions in one select"
check "SUCCESS_5402: successful sudo to root (rule 5402)" '[ "$(_kv $A SUCCESS_5402)" = "$(_n ".rule.id == \"5402\"")" ]' "rule.id 5402"
check "FAILER_5402: rule-5402 alerts for that user" '[ "$(_kv $A FAILER_5402)" = "$(_n ".rule.id == \"5402\" and .data.srcuser == \"$(_top_failer)\"")" ]' "The course stops here"

section "2. What rule 5402 does not show"
check "FIRST_TIME_RULE: the rule a first successful sudo gets instead of 5402" '[ "$(_kv $A FIRST_TIME_RULE)" = 5403 ]' \
  "List every rule.id for that user, not only 5401 and 5402"
check "FAILER_ROOT_TOTAL: all successful sudo to root by that user" '[ "$(_kv $A FAILER_ROOT_TOTAL)" = "$(_n "(.rule.id == \"5402\" or .rule.id == \"5403\") and .data.dstuser == \"root\" and .data.srcuser == \"$(_top_failer)\"")" ]' \
  "5402 plus 5403, target root"
check "ESCALATION_BINARY: the program sudo let that user run as root" '[ "$(_kv $A ESCALATION_BINARY)" = vim ]' ".data.command; look it up on GTFOBins"
check "BACKDOOR_USER: the account created right after" '[ "$(_kv $A BACKDOOR_USER)" = sysupd ]' "Rule 5902, and its UID"

section "3. A rule for it (100300)"
check "Rule 100300 (level 12) fires on sudo to root into vim" '_has && [ "$(_rule "$(_line dkim root "/usr/bin/vim /etc/nginx/nginx.conf")")" = 100300 ] && grep -qE "<rule[^>]*id=\"100300\"[^>]*level=\"12\"|<rule[^>]*level=\"12\"[^>]*id=\"100300\"" $O/etc/rules/*.xml' \
  "if_sid 5402 and 5403, a field match on command; restart the manager"
check "...and into the other listed shell-escape programs" '_has && [ "$(_rule "$(_line ana root "/usr/bin/less /var/log/syslog")")" = 100300 ] && [ "$(_rule "$(_line ana root "/usr/bin/find / -name x")")" = 100300 ] && [ "$(_rule "$(_line ana root "/bin/bash")")" = 100300 ]' \
  "less, find, bash, ..."
check "...but not on ordinary admin commands" '_has && [ "$(_rule "$(_line dkim root "/usr/bin/vim /etc/nginx/nginx.conf")")" = 100300 ] && [ "$(_rule "$(_line sarah root "/usr/bin/systemctl restart nginx")")" != 100300 ] && [ "$(_rule "$(_line sarah root "/usr/bin/journalctl -u nginx")")" != 100300 ]' \
  "Match the program, not any word in the command"
check "...nor when the target is not root" '_has && [ "$(_rule "$(_line dkim root "/usr/bin/vim /etc/nginx/nginx.conf")")" = 100300 ] && [ "$(_rule "$(_line sarah www-data "/usr/bin/vim /var/www/index.html")")" != 100300 ]' \
  "Sudo to another user is a different parent rule"
