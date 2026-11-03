# Checks for bash-functions (see templates/lab/check.sh for the rules).
# Every check runs the code in a fresh bash, so it tests behaviour.

K=/root/scripts/toolkit.sh
_k() { bash -c "source $K >/dev/null 2>&1 || exit 99; $1"; }

section "1. total()"
check "toolkit.sh defines total" '[ -f $K ] && _k "declare -F total" >/dev/null' "total() { ...; }"
check "total 1 2 3 4 prints 10" '[ "$(_k "total 1 2 3 4")" = 10 ]' "Loop over \"\$@\" and add with \$(( ))"
check "total with no arguments prints 0" '[ -f $K ] && [ "$(_k "total")" = 0 ]' "Start the sum at 0"
check "total handles negative numbers" '[ "$(_k "total -5 5 12")" = 12 ]' "\$(( sum + n )) works for negative integers"
check "A non-number makes it return 2 with a message on stderr" '[ -f $K ] && _k "total 1 x 3" >/dev/null 2>/tmp/kerr; [ $? = 2 ] && [ -s /tmp/kerr ] && [ -z "$(_k "total 1 x 3" 2>/dev/null)" ]' \
  "Check each argument with [[ \$n =~ ^-?[0-9]+\$ ]]; echo the error >&2 and return 2 before printing a total"

section "2. is_root()"
check "is_root returns 0 for root" '[ -f $K ] && _k "is_root"' "[[ \$EUID -eq 0 ]]"
check "is_root returns 1 for a normal user" '[ -f $K ] && as_user operator2 "source $K || exit 9; is_root; [ \$? = 1 ]"' "return 1, not exit 1"
check "is_root returns instead of exiting the caller" '[ -f $K ] && [ "$(as_user operator2 "source $K || exit 9; is_root; echo still-here")" = still-here ]' \
  "exit in a sourced function ends the whole shell"

section "3. A well-behaved library"
check "Sourcing it prints nothing" '[ -f $K ] && [ -z "$(bash -c "source $K" 2>&1)" ]' "A library only defines functions"
check "Its functions don't leak variables" '[ -f $K ] && [ -z "$(_k "a=\$(compgen -v | sort); total 4 5 >/dev/null; total 1 y >/dev/null 2>&1; is_root; b=\$(compgen -v | sort); comm -13 <(echo \"\$a\") <(echo \"\$b\") | grep -v -e ^a\$ -e ^_\$ -e ^BASH_REMATCH\$")" ]' \
  "Declare every variable inside a function with local"

section "4. report.sh uses the library"
R=/root/scripts/report.sh
check "report.sh is executable and sources toolkit.sh" '[ -x $R ] && grep -Eq "(source|\.) .*toolkit\.sh" $R' "source \"\$(dirname \"\$0\")/toolkit.sh\""
check "It prints 'total of 1 2 3 4 = 10'" '[ -x $R ] && [ "$(cd /root/scripts && ./report.sh)" = "total of 1 2 3 4 = 10" ]' "Call total, don't hard-code 10"
check "It also works from another directory" '[ -x $R ] && [ "$(cd / && /root/scripts/report.sh 2>/dev/null)" = "total of 1 2 3 4 = 10" ]' \
  "A relative path like ./toolkit.sh depends on where you are; build it from \$0 or BASH_SOURCE"

section "5. relay.sh passes exit codes on"
P=/root/scripts/relay.sh
check "relay.sh false exits 1" '[ -x $P ] && { "$P" false 2>/dev/null; [ $? = 1 ]; }' "Run \"\$@\", then save \$? immediately"
check "relay.sh sh -c \"exit 7\" exits 7" '[ -x $P ] && { "$P" sh -c "exit 7" 2>/dev/null; [ $? = 7 ]; }' "exit \"\$rc\""
check "relay.sh true exits 0" '[ -x $P ] && "$P" true 2>/dev/null' "Success must stay success"
check "It reports the code on stderr" '[ -x $P ] && "$P" sh -c "exit 7" 2>&1 >/dev/null | grep -q "exited with 7"' \
  "echo \"command exited with \$rc\" >&2 (any echo in between would overwrite \$?)"
check "It passes the command's own output through" '[ -x $P ] && [ "$("$P" echo relayed 2>/dev/null)" = relayed ]' "Don't swallow stdout"
