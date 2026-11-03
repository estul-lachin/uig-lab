# Checks for bash-traps-signals (see templates/lab/check.sh for the rules).
# Most checks run the scripts, so they test behaviour, not just text.

D=/root/scripts

section "1. Cleanup trap (cleanup.sh)"
C=$D/cleanup.sh
_run_cleanup() { rm -f $D/last-tmpdir.txt; "$C" "$1"; }
check "cleanup.sh is executable" '[ -x $C ]' "chmod +x"
check "It uses mktemp -d and an EXIT trap" 'grep -q "mktemp -d" $C && grep -Eq "trap .+ EXIT" $C' "trap 'rm -rf \"\$tmp\"' EXIT"
check "It records a temp dir that is gone after a normal exit" '[ -x $C ] && _run_cleanup 0 && t=$(cat $D/last-tmpdir.txt) && [ -n "$t" ] && [ "${t#/tmp/}" != "$t" ] && [ ! -e "$t" ]' \
  "Write the mktemp -d path to /root/scripts/last-tmpdir.txt; the trap removes the directory"
check "It exits with the status given as \$1, and still cleans up" '[ -x $C ] && { _run_cleanup 3; [ $? = 3 ]; } && t=$(cat $D/last-tmpdir.txt) && [ -n "$t" ] && [ ! -e "$t" ]' \
  "exit \"\${1:-0}\": the EXIT trap runs whatever the exit status"

section "2. SIGINT handler (graceful.sh)"
G=$D/graceful.sh
L=$D/graceful.log
check "graceful.sh is executable and traps INT" '[ -x $G ] && grep -Eq "trap .+ (INT|SIGINT)" $G' "trap 'on_int' INT"
check "On Ctrl+C it exits with status 130" '[ -x $G ] && rm -f $L && { timeout --preserve-status -s INT 2 "$G" >/dev/null 2>&1; [ $? = 130 ]; }' \
  "Keep running (while true; do sleep 1; done) until interrupted; in the handler: exit 130"
check "It writes 'caught SIGINT' to graceful.log" '[ -f $L ] && grep -qx "caught SIGINT" $L' "echo \"caught SIGINT\" >> /root/scripts/graceful.log"

section "3. ERR trap (errtrap.sh)"
E=$D/errtrap.sh
check "errtrap.sh uses set -euo pipefail and an ERR trap" '[ -x $E ] && grep -q "set -euo pipefail" $E && grep -Eq "trap .+ ERR" $E' "trap '...' ERR"
check "It reports the line of the failing ls" '[ -x $E ] && n=$(grep -n "ls /does-not-exist" $E | head -n1 | cut -d: -f1) && [ -n "$n" ] && "$E" 2>&1 >/dev/null | grep -q "error on line $n"' \
  "trap 'echo \"error on line \$LINENO\" >&2' ERR, and a line ls /does-not-exist"
check "It stops there and exits non-zero" '[ -x $E ] && grep -q unreachable $E && ! "$E" 2>/dev/null | grep -q unreachable && ! "$E" >/dev/null 2>&1' \
  "Put echo unreachable after the failing command; set -e must stop before it"

section "4. Strict defaults (strict.sh)"
T=$D/strict.sh
check "Line 1 is #!/usr/bin/env bash" '[ "$(head -n1 $T 2>/dev/null)" = "#!/usr/bin/env bash" ]' "env finds bash wherever it is installed"
check "It sets -Eeuo pipefail and IFS" 'grep -q "^set -Eeuo pipefail" $T && grep -qF "IFS=\$'"'"'\n\t'"'"'" $T' "set -Eeuo pipefail, then IFS=\$'\\n\\t'"
check "It greets its argument" '[ -x $T ] && [ "$("$T" Robin 2>/dev/null)" = "hello Robin" ]' "echo \"hello \$1\""
check "Without an argument it fails instead of greeting nobody" '[ -x $T ] && "$T" Robin >/dev/null 2>&1 && ! "$T" >/dev/null 2>&1' \
  "set -u turns the unset \$1 into an error"

section "5. Fix prune-logs.sh"
P=$D/prune-logs.sh
_sandbox() { rm -rf /tmp/plab; mkdir -p /tmp/plab/logs; touch /tmp/plab/logs/old-a.log /tmp/plab/logs/current.log /old-canary.log; }
check "With LOGDIR set it still prunes only old-*.log" '[ -x $P ] && _sandbox && LOGDIR=/tmp/plab/logs "$P" >/dev/null 2>&1 && [ ! -e /tmp/plab/logs/old-a.log ] && [ -e /tmp/plab/logs/current.log ]' \
  "Keep the rm line working"
check "Without LOGDIR it refuses and deletes nothing" '[ -x $P ] && _sandbox && ! env -u LOGDIR "$P" >/dev/null 2>&1 && [ -e /old-canary.log ]' \
  "An unset LOGDIR turns \"\$LOGDIR\"/old-*.log into /old-*.log. Use set -u or \${LOGDIR:?LOGDIR not set}"
rm -rf /tmp/plab /old-canary.log
