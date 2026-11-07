# Checks for jwt-auth-bypass (see templates/lab/check.sh for the rules).
# Runs inside the container. Every check is default-false: a fresh box has blank
# answers and no /flag/solved, so nothing passes until the learner forges an
# admin token the server accepts.

ANS=/root/answers.txt
FLAG=/flag/solved

val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]' ; }

vuln_alg_ok()  { [ "$(norm "$(val VULN_ALG)")" = none ]; }
forged_ok()    { printf '%s' "$(val FORGED_CLAIM)" | grep -qi 'role'; }
fix_ok()       { printf '%s' "$(val FIX)" | grep -qiE 'pin|allow ?list|white ?list|reject none|expect|specify|hard ?code|do ?n.?t trust|server.?side|verify.*alg|fixed alg'; }

flag_present() { [ -f "$FLAG" ]; }
# The flag is written by /admin only for a token whose role claim is admin.
flag_admin()   { grep -qi 'role:[[:space:]]*admin' "$FLAG" 2>/dev/null; }

section "1. Recon: read the token"
check "answers.txt: the alg value that skips signature verification is 'none'" \
  'vuln_alg_ok' "{\"alg\":\"none\"} makes a broken verifier accept an unsigned token"
check "answers.txt: you forged the 'role' claim to become admin" \
  'forged_ok' "the payload carries role=user; change it to role=admin"

section "2. Exploit: forge an admin token"
check "/flag/solved exists (the server accepted a forged admin token)" \
  'flag_present' "set alg:none, role:admin, drop the signature, then call /admin"
check "the flag shows an admin takeover (role: admin)" \
  'flag_admin' "the /admin endpoint records the role it authenticated you as"

section "3. Name the fix"
check "answers.txt: names the correct fix (pin/allow-list the algorithm, reject none)" \
  'fix_ok' "the server must pin the expected alg server-side and never trust the header"
