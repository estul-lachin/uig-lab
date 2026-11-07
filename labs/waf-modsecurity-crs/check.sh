# Checks for waf-modsecurity-crs (see templates/lab/check.sh for the rules).
# Runs inside the WAF container. It attacks the live WAF (localhost:8080) and reads
# the result, so every check is default-false: while the engine is in DetectionOnly
# with no custom rule and blank answers, nothing is blocked and nothing passes.

WAF="http://localhost:8080"
ANS=/root/answers.txt
AUDIT=/var/log/modsec/audit.log

# The image's entrypoint templates the nginx config in several steps before nginx
# starts; probing too early gets no answer. Wait until the WAF answers.
for _ in $(seq 1 60); do curl -s -o /dev/null http://localhost:8080/ && break; sleep 1; done

# Drive the WAF once up front: a SQL-injection probe and a request carrying the
# custom-rule marker. Capture the status codes for the checks below.
SQLI_CODE="$(curl -s -o /dev/null -w '%{http_code}' -G "$WAF/search" --data-urlencode "id=1' OR '1'='1" 2>/dev/null)"
MARK_CODE="$(curl -s -o /dev/null -w '%{http_code}' -G "$WAF/search" --data-urlencode "q=malbeacon" 2>/dev/null)"
BENIGN_CODE="$(curl -s -o /dev/null -w '%{http_code}' "$WAF/" 2>/dev/null)"
sleep 1  # let the audit log flush

val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]' ; }

master_ok()   { [ "$(norm "$(val MASTER_SWITCH)")" = secruleengine ]; }
alertonly_ok(){ [ "$(norm "$(val ALERT_ONLY)")" = detectiononly ]; }
blockcode_ok(){ [ "$(norm "$(val BLOCK_CODE)")" = 403 ]; }
howdecides_ok(){ printf '%s' "$(norm "$(val HOW_DECIDES)")" | grep -q 'anomaly'; }
sqlifam_ok()  { printf '%s' "$(val SQLI_FAMILY)" | grep -q '942'; }

# Enforcement is On only when the SQLi is blocked (403) AND benign traffic still
# passes (200) - combined so a fresh DetectionOnly env (SQLi passes) cannot pass.
enforce_ok()    { [ "$SQLI_CODE" = 403 ] && [ "$BENIGN_CODE" = 200 ]; }
marker_blocked(){ [ "$MARK_CODE" = 403 ]; }
# A blocked (interrupted) transaction that matched a 942 SQLi rule. In DetectionOnly
# the rule still logs but is_interrupted is false, so this stays default-false.
audit_has_sqli(){ grep '"is_interrupted":true' "$AUDIT" 2>/dev/null | grep -qE '942[0-9]{3}'; }

section "1. WAF / CRS concepts"
check "answers.txt: the master switch directive is SecRuleEngine" \
  'master_ok' "SecRuleEngine On | DetectionOnly | Off"
check "answers.txt: the alert-only (inspect but never block) value is DetectionOnly" \
  'alertonly_ok' "the WAF equivalent of an IDS alert-only mode - safe for tuning"
check "answers.txt: CRS returns HTTP 403 when it blocks" \
  'blockcode_ok' "the block status code"
check "answers.txt: CRS decides by anomaly scoring (not one rule = one block)" \
  'howdecides_ok' "each matching rule adds to a score; past the threshold it blocks"
check "answers.txt: the SQL-injection CRS rule family is 942" \
  'sqlifam_ok' "941=XSS, 942=SQLi, 930=LFI/traversal, 932=RCE"

section "2. Turn on enforcement"
check "a SQL-injection request is blocked with 403 while benign traffic still returns 200" \
  'enforce_ok' "set SecRuleEngine On in the override and reload; fresh env is DetectionOnly (passes through)"

section "3. Write a custom rule and read the cause"
check "your custom SecRule blocks requests carrying the 'malbeacon' marker (403)" \
  'marker_blocked' "SecRule ARGS \"@contains malbeacon\" \"id:900100,phase:2,deny,status:403,msg:'...'\" then reload"
check "the audit log records the SQLi CRS rule family (942...) for the blocked request" \
  'audit_has_sqli' "read /var/log/modsec/audit.log - the matched rule id tells you the attack class"
