# Checks for siem-correlation-rules (see templates/lab/check.sh for the rules).
# Feeds sshd lines through wazuh-logtest and looks at which rule each one ends in.

O=/var/ossec
A=/root/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]" | tr A-Z a-z; }
_in() { local v; v=$(_kv $A "$1"); [ -n "$v" ] && for x in $2; do [ "$v" = "$x" ] && return 0; done; return 1; }
# _seq IP FAILS [LOGIN_IP USER]: FAILS failed root passwords from IP, then optionally one accepted login
_seq() {
  local i
  for i in $(seq 1 "$2"); do printf "Nov  3 15:01:%02d srv sshd[2%03d]: Failed password for root from %s port 4%04d ssh2\n" $i $i "$1" $i; done
  if [ -n "${3:-}" ]; then printf "Nov  3 15:02:00 srv sshd[2999]: Accepted password for %s from %s port 50001 ssh2\n" "$4" "$3"; fi
}
# _lt: the result of each event as RULE:LEVEL:alert|quiet, one per line (logtest writes to stderr)
_lt() {
  $O/bin/wazuh-logtest 2>&1 | grep -E "^[[:space:]]+(id|level): '|Alert to be|Phase 1" | awk -F"'" '
    function out() { if (r != "") print r ":" l ":" (a ? "alert" : "quiet"); r = ""; l = ""; a = 0 }
    /Phase 1/ { out(); next }
    /id: /    { r = $2 }
    /level: / { l = $2 }
    /Alert to be/ { a = 1 }
    END { out() }'
}
_last() { _seq "$@" | _lt | tail -n1; }
_has() { grep -qE "<rule[^>]*id=\"$1\"" $O/etc/rules/*.xml 2>/dev/null; }

for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done

section "1. The QRadar vocabulary"
check "BUILDING_BLOCK is the reusable unit" '_in BUILDING_BLOCK "buildingblock buildingblocks"' "Not malicious on its own"
check "RULE is the correlation logic" '_in RULE "rule rules"' "Built from building blocks"
check "OFFENSE is the incident container" '_in OFFENSE "offense offenses"' "What an analyst gets assigned"
check "ORDERED_BY is what the Offenses tab sorts by" '_in ORDERED_BY magnitude' "Severity, relevance and credibility blended"
check "RULE_TOOL is where rules are written" '_in RULE_TOOL "rulewizard"' "A wizard"

section "2. The building block"
L=$O/etc/lists/privileged-accounts
check "The CDB list privileged-accounts has exactly root, administrator and svc_backup" '[ "$(cut -d: -f1 $L 2>/dev/null | grep . | sort | paste -sd,)" = administrator,root,svc_backup ]' \
  "One key per line, KEY: (a colon at the end)"
check "It is registered in ossec.conf and the configuration is valid" 'grep -q "<list>etc/lists/privileged-accounts</list>" $O/etc/ossec.conf && $O/bin/wazuh-analysisd -t >/dev/null 2>&1' \
  "<ruleset> ... <list>, then wazuh-analysisd -t"
check "Rule 100100 matches a root login and stays silent (no alert)" '_has 100100 && [ "$(_last 192.0.2.9 0 192.0.2.9 root)" = 100100:0:quiet ]' \
  "Child of 5715 at level 0; restart the manager after changes"
check "...but not a login by an ordinary user" '_has 100100 && [ "$(_last 192.0.2.9 0 192.0.2.9 root | cut -d: -f1)" = 100100 ] && [ "$(_last 192.0.2.9 0 192.0.2.9 maria | cut -d: -f1)" = 5715 ]' \
  "Only users in the list"

section "3. The threshold rule"
check "Rule 100110 fires (level 10) on the 6th failed password from one address" '_has 100110 && [ "$(_last 192.0.2.9 6)" = 100110:10:alert ]' \
  "frequency, timeframe 300, same source address, on 5760"
check "...not on the 5th" '_has 100110 && [ "$(_last 192.0.2.9 6 | cut -d: -f1)" = 100110 ] && [ "$(_last 192.0.2.9 5 | cut -d: -f1)" != 100110 ]' "Count carefully"

section "4. The correlation rule"
check "Rule 100120 (level 14) fires on a privileged login right after the burst, same address" '_has 100120 && [ "$(_last 192.0.2.9 8 192.0.2.9 root)" = 100120:14:alert ]' \
  "Child of 100100, with 100110 matched before it from the same address"
check "...not when the login comes from a different address" '[ "$(_last 192.0.2.9 8 192.0.2.9 root | cut -d: -f1)" = 100120 ] && [ "$(_last 192.0.2.9 8 198.51.100.4 root | cut -d: -f1)" != 100120 ]' \
  "same_srcip"
check "...and not without a burst first" '[ "$(_last 192.0.2.9 8 192.0.2.9 root | cut -d: -f1)" = 100120 ] && [ "$(_last 192.0.2.9 3 192.0.2.9 root | cut -d: -f1)" != 100120 ]' \
  "if_matched_sid"
