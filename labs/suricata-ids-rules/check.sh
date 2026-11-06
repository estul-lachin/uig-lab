# Checks for suricata-ids-rules (see templates/lab/check.sh for the rules).
# Every check is default-false: a fresh box has blank answers, a local.rules with
# no active rule, and no eve.json yet - so nothing passes until the learner writes
# signatures, runs Suricata against the capture, and reads the alerts.

ANS=/root/answers.txt
RULES=/root/local.rules
EVE=/var/log/suricata/eve.json

val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]' ; }

passive_copy_ok() { v="$(norm "$(val PASSIVE_COPY)")"; case "$v" in *tap*|*span*|*mirror*) return 0;; esac; return 1; }
passive_tool_ok() { [ "$(norm "$(val PASSIVE_TOOL)")" = zeek ]; }
output_file_ok()  { [ "$(norm "$(val OUTPUT_FILE)")" = eve.json ]; }

# An active (uncommented) alert rule carrying a content match and a unique local
# sid (>= 1000000 -> a 7+ digit id starting 1-9).
rule_ok() {
  grep -E '^[[:space:]]*alert ' "$RULES" 2>/dev/null \
    | grep 'content:' \
    | grep -qE 'sid:[[:space:]]*[1-9][0-9]{6,}'
}

# True when an alert event line in eve.json carries the given attack fingerprint.
alert_has() { grep '"event_type":"alert"' "$EVE" 2>/dev/null | grep -qF "$1"; }

section "1. IDS/IPS concepts"
check "answers.txt: a passive IDS gets its copy of traffic from a TAP or SPAN/mirror port" \
  'passive_copy_ok' "an inline IPS sits in the path; a passive IDS only sees a mirrored copy"
check "answers.txt: the passive-only tool is Zeek" \
  'passive_tool_ok' "Suricata and Snort can run inline (IPS); Zeek only analyses/logs"
check "answers.txt: Suricata's event output file is eve.json" \
  'output_file_ok' "the EVE JSON log SOCs read alerts from"

section "2. Write a signature"
check "local.rules has an active alert rule with a content match and a unique sid (1000000+)" \
  'rule_ok' "action header options: alert ... content:\"...\"; sid:1000001;"

section "3. Run Suricata and confirm the alerts fired"
check "an alert fired on the SQL-injection request (the OR tautology)" \
  'alert_has "+OR+"' "run: suricata -r /opt/pcaps/larkspur-traffic.pcap -S /root/local.rules -l /var/log/suricata"
check "an alert fired on the path-traversal request (../ in the URL)" \
  'alert_has "../"' "match ../ in http.uri"
check "an alert fired on the scanner User-Agent (EvilScan)" \
  'alert_has "EvilScan"' "match the EvilScan string in http.user_agent"
