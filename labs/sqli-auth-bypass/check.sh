# Checks for sqli-auth-bypass (see templates/lab/check.sh for the rules).
# Every check is default-false: on a fresh environment answers.txt is blank and
# the flag file does not exist, so nothing passes until the learner bypasses the
# login with SQL injection and records what they did.

ANS=/root/answers.txt
FLAG=/flag/solved

# value of KEY= from answers.txt (everything after the first '=')
val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
# lowercase, strip all whitespace
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]' ; }

param_ok()    { p="$(norm "$(val PARAM)")"; [ "$p" = username ] || [ "$p" = password ]; }
# an injection payload carries a single quote AND either a SQL comment (--) or OR
payload_ok()  { v="$(val PAYLOAD)"; printf '%s' "$v" | grep -q "'" \
                 && printf '%s' "$v" | grep -qiE -- "--|\\bor\\b"; }
technique_ok(){ t="$(norm "$(val TECHNIQUE)")"; [ "$t" = comment ] || [ "$t" = tautology ]; }
flag_present(){ [ -f "$FLAG" ]; }
flag_admin()  { grep -qi 'bypassed-account:[[:space:]]*admin' "$FLAG" 2>/dev/null; }

section "1. Recon: find the injection point"
check "answers.txt names the field you injected into (username or password)" \
  'param_ok' "the login form POSTs username and password; one of them reaches the SQL"
check "answers.txt records an injection payload (a quote plus -- or OR)" \
  'payload_ok' "e.g.  admin' --  or  ' OR '1'='1"
check "answers.txt names the technique (comment or tautology)" \
  'technique_ok' "-- comments out the password check; ' OR '1'='1 makes WHERE always true"

section "2. Capture the flag: prove the auth bypass"
check "the flag file /flag/solved exists" \
  'flag_present' "written only on a successful admin login with a wrong password"
check "the flag shows the bypassed account was 'admin'" \
  'flag_admin' "you logged in as admin without the real password - that is the bypass"
