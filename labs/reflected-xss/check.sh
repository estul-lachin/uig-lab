# Checks for reflected-xss (see templates/lab/check.sh for the rules).
# Every check is default-false: on a fresh environment answers.txt is blank and
# the flag file does not exist, so nothing passes until the learner exploits the
# reflected XSS and records what they found.

ANS=/root/answers.txt
FLAG=/flag/solved

# value of KEY= from answers.txt (everything after the first '=')
val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
# lowercase, strip all whitespace
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]' ; }

ctx_ok()      { [ "$(norm "$(val CONTEXT)")" = attribute ]; }
breakout_ok() { b="$(val BREAKOUT)"; printf '%s' "$b" | grep -q '"' && printf '%s' "$b" | grep -q '>'; }
payload_ok()  { p="$(val PAYLOAD)";  printf '%s' "$p" | grep -qi '<script' && printf '%s' "$p" | grep -qi 'xss-hit'; }
flag_present(){ [ -f "$FLAG" ]; }
flag_cookie() { grep -q 'modsession=MODSESS-' "$FLAG" 2>/dev/null; }

section "1. Recon: locate and classify the reflection"
check "answers.txt names the reflection context as 'attribute'" \
  'ctx_ok' "q is echoed inside an HTML attribute (value=\"...\"), not a bare text node"
check "answers.txt records the attribute break-out characters" \
  'breakout_ok' "to escape value=\"...\" you must close the quote and the tag: \">"

section "2. Exploit: a reflected script that calls back"
check "answers.txt PAYLOAD is a <script> that reaches the /xss-hit callback" \
  'payload_ok' "break out of the attribute, then <script>...fetch the /xss-hit callback...</script>"

section "3. Capture the flag: proof the script really executed"
check "the flag file /flag/solved exists" \
  'flag_present' "the server writes it only when the callback actually fires"
check "the flag proves the moderator's session cookie was stolen" \
  'flag_cookie' "the callback carried document.cookie - curling /xss-hit by hand cannot fake this"
