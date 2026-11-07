# Checks for wazuh-fim-intrusion (see templates/lab/check.sh for the rules).

O=/var/ossec
AL=$O/logs/alerts/alerts.json
A=/root/answers.txt
MARK=/var/lib/lab-intrusion-done
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
# _win JQ-FILTER: FIM alerts from the intrusion window (before the marker time) that match
_win() { jq -c --argjson end "$(cat $MARK 2>/dev/null || echo 0)" \
  "select(.syscheck.path != null) | select((.timestamp[0:19] + \"Z\" | fromdate) <= \$end) | select($1)" $AL 2>/dev/null; }
_n() { _win "$1" | wc -l | tr -d " "; }
_persist() { _win '.rule.id == "554" and (.syscheck.path | startswith("/etc/cron.d/"))' | jq -r '.syscheck.path' | head -n1; }
_has() { grep -qE "<rule[^>]*id=\"100310\"" $O/etc/rules/*.xml 2>/dev/null; }
# Real-time FIM is watching again after the last (re)start of syscheckd
_rt() { awk '/\(6000\)/ {s = NR} /\(6012\)/ {r = NR} END {exit !(s && r > s)}' $O/logs/ossec.log; }
# _drop DIR: add a file in DIR, print the rule of its "added" alert (empty if none), remove the file
_drop() {
  _f="$1/lab-check-$$-$RANDOM"; _r=""
  for _ in $(seq 1 30); do _rt && break; sleep 2; done
  echo "check $(date +%s)" > "$_f"
  for _ in $(seq 1 20); do
    _r=$(jq -r --arg p "$_f" 'select(.syscheck.path == $p and .syscheck.event == "added") | .rule.id' $AL 2>/dev/null | head -n1)
    [ -n "$_r" ] && break; sleep 1
  done
  rm -f "$_f"; echo "$_r"
}

for _ in $(seq 1 60); do [ -f $MARK ] && break; sleep 5; done

section "0. Wazuh is ready"
check "The manager is up and the intrusion has been recorded by FIM" '[ -f $MARK ] && [ "$(_n "true")" -ge 10 ]' \
  "The manager needs a minute or two after ./lab up; run the check again"

section "1. The core questions"
check "MODIFIED_550: files modified (rule 550)" '[ "$(_kv $A MODIFIED_550)" = "$(_n ".rule.id == \"550\"")" ]' "jq select on .rule.id, then count lines"
check "ADDED_554: files added (rule 554)" '[ "$(_kv $A ADDED_554)" = "$(_n ".rule.id == \"554\"")" ]' "The same, another rule id"
check "DELETED_553: files deleted (rule 553)" '[ "$(_kv $A DELETED_553)" = "$(_n ".rule.id == \"553\"")" ]' "Which directory were they in?"
check "PERSISTENCE_FILE: the file added under /etc/cron.d" '[ -n "$(_persist)" ] && [ "$(_kv $A PERSISTENCE_FILE)" = "$(_persist)" ]' \
  "Print .syscheck.path for the added files; the full path"
check "FIM_TOTAL: all FIM events of the intrusion" '[ "$(_kv $A FIM_TOTAL)" = "$(_n ".rule.id == \"550\" or .rule.id == \"553\" or .rule.id == \"554\"")" ]' \
  "rule.groups contains syscheck, or the sum of the three"

section "2. What the diffs say"
check "SSHD_SETTING: the sshd_config setting the intruder changed" '[ "$(_kv $A SSHD_SETTING)" = PermitRootLogin ]' \
  ".syscheck.diff of the sshd_config alert"
check "EXFIL_HOST: where the changed backup script now sends the backup" '[ "$(_kv $A EXFIL_HOST)" = 203.0.113.47 ]' \
  "Read every diff, not only the one in /etc/ssh"
check "WEBSHELL: the added file the changed index.php now loads" '[ "$(_kv $A WEBSHELL)" = /var/www/html/uploads/.thumb.php ]' \
  "Join the index.php diff to one of the added files: full path"
check "CRON_RUNS: the program the new cron job runs" '[ "$(_kv $A CRON_RUNS)" = /usr/local/bin/kworkerd ]' \
  "An added file has no diff: read the file on disk. Full path"

section "3. A rule for new cron jobs (100310)"
check "Rule 100310 (level 12) exists and the manager loads it" '_has && grep -qE "<rule[^>]*id=\"100310\"[^>]*level=\"12\"|<rule[^>]*level=\"12\"[^>]*id=\"100310\"" $O/etc/rules/*.xml && $O/bin/wazuh-analysisd -t >/dev/null 2>&1' \
  "id and level on the rule tag; validate with wazuh-analysisd -t, then restart"
check "A new file in /etc/cron.d raises rule 100310" '_has && [ "$(_drop /etc/cron.d)" = 100310 ]' \
  "A child of 554 with a field match on the file path; restart the manager"
check "...and a new file in /etc/cron.daily too" '_has && [ "$(_drop /etc/cron.daily)" = 100310 ]' \
  "All the cron directories, not just cron.d"
check "...but a new file in the web root stays an ordinary 554" '_has && [ "$(_drop /var/www/html/uploads)" = 554 ]' \
  "Anchor the path match at the start"
