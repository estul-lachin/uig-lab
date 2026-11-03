# Checks for bash-variables-quoting (see templates/lab/check.sh for the rules).
# The checks run your scripts; most run from /root/scripts, where files exist for * to match.

D=/root/scripts
_in() { (cd $D && "$@" 2>/dev/null); }
_rc() { (cd $D && "$@" >/dev/null 2>&1); echo $?; }

section "1. welcome.sh"
W=$D/welcome.sh
check "It is executable and uses set -euo pipefail" '[ -x $W ] && grep -q "set -euo pipefail" $W' "chmod +x; set -euo pipefail near the top"
check "welcome.sh \"Grace Hopper\" prints Welcome, Grace Hopper!" '[ -x $W ] && [ "$(_in $W "Grace Hopper")" = "Welcome, Grace Hopper!" ]' 'echo "Welcome, $1!"'
check "Double spaces and * survive" '[ -x $W ] && [ "$(_in $W "a  b")" = "Welcome, a  b!" ] && [ "$(_in $W "*")" = "Welcome, *!" ]' \
  "Unquoted, \$1 is split (spaces collapse) and globbed (* becomes the file names): quote it"
check "Without a name it fails" '[ -x $W ] && [ "$(_rc $W)" != 0 ]' "set -u makes the unset \$1 an error"

section "2. Passing arguments on"
A=$D/args.sh
F=$D/forward.sh
check "args.sh \"a b\" c prints 2 args: [a b] [c]" '[ -x $A ] && [ "$(_in $A "a b" c)" = "2 args: [a b] [c]" ]' \
  "echo -n \"\$# args:\"; then printf \" [%s]\" \"\$@\"; then a newline"
check "args.sh with no arguments prints 0 args:" '[ -x $A ] && [ "$(_in $A)" = "0 args:" ]' "printf with \"\$@\" and no arguments still prints the format once"
check "forward.sh passes its arguments to args.sh unchanged" '[ -x $F ] && [ -x $A ] && [ "$(_in $F "x  y" "" "*")" = "3 args: [x  y] [] [*]" ]' \
  "\"\$@\" keeps each argument whole, even empty ones; \$@ or \$* unquoted breaks them"

section "3. Parameter expansion (pathparts.sh)"
P=$D/pathparts.sh
_pp() { printf "dir=%s\nfile=%s\next=%s\nstem=%s\nupper=%s" "$@"; }
check "It splits /var/log/nginx/access.log.gz" '[ -x $P ] && [ "$(_in $P /var/log/nginx/access.log.gz)" = "$(_pp /var/log/nginx access.log.gz gz access.log ACCESS.LOG.GZ)" ]' \
  "\${p%/*} \${p##*/} \${file##*.} \${file%.*} \${file^^}"
check "It works with spaces in the path" '[ -x $P ] && [ "$(_in $P "/srv/case files/Report v2.pdf")" = "$(_pp "/srv/case files" "Report v2.pdf" pdf "Report v2" "REPORT V2.PDF")" ]' "Quote every expansion"
check "It uses only parameter expansion" '[ -x $P ] && ! grep -Eq "(basename|dirname|tr |sed |awk |cut )" $P' "No external commands: \${...} only"

section "4. Defaults and required values (settings.sh)"
S=$D/settings.sh
check "Defaults apply when nothing is set" '[ -x $S ] && [ "$(cd $D && env -u LOGDIR -u LEVEL API_HOST=h1 $S 2>/dev/null)" = "$(printf "LOGDIR=/var/log/app\nLEVEL=info\nAPI_HOST=h1")" ]' \
  "\${LOGDIR:-/var/log/app}, \${LEVEL:-info}"
check "Set values win over defaults" '[ -x $S ] && [ "$(cd $D && LOGDIR=/tmp/x LEVEL=debug API_HOST=h2 $S 2>/dev/null)" = "$(printf "LOGDIR=/tmp/x\nLEVEL=debug\nAPI_HOST=h2")" ]' "Don't hard-code the output"
check "An empty LEVEL also falls back to info" '[ -x $S ] && (cd $D && LEVEL= API_HOST=h $S 2>/dev/null) | grep -qx "LEVEL=info"' \
  "\${LEVEL:-info} (with the colon) covers empty too; \${LEVEL-info} only unset"
check "Without API_HOST it stops with a message and prints nothing" '[ -x $S ] && out=$(cd $D && env -u API_HOST $S 2>/tmp/serr); rc=$?; [ $rc != 0 ] && [ -z "$out" ] && grep -q API_HOST /tmp/serr' \
  "Check \${API_HOST:?API_HOST must be set} before printing anything"

section "5. Masking secrets (mask.sh)"
M=$D/mask.sh
check "It replaces every occurrence of the secret" '[ -x $M ] && [ "$(_in $M "key=s3cr3t retry key=s3cr3t" s3cr3t)" = "key=****** retry key=******" ]' \
  "\${line//\"\$secret\"/\$stars}: two slashes replace all"
check "The stars match the secret's length" '[ -x $M ] && [ "$(_in $M "pw=ab" ab)" = "pw=**" ]' "\${#secret} is its length; build the stars in a loop or with printf"
check "Glob characters in the secret are taken literally" '[ -x $M ] && [ "$(_in $M "a*c abc" "a*c")" = "*** abc" ]' \
  "Quote the pattern: \${line//\"\$secret\"/...}, or * matches anything"
