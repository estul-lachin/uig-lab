# Checks for command-injection (see templates/lab/check.sh for the rules).
# Runs inside the container. Every check is default-false: a fresh box has blank
# answers and no /flag/solved, so nothing passes until the learner injects a
# command that runs on the host.

ANS=/root/answers.txt
FLAG=/flag/solved

val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]' ; }

# A shell command separator / substitution metacharacter.
operator_ok() { printf '%s' "$(val OPERATOR)" | grep -qE ';|&&|\|\||\||\$\(|`'; }
# Impact is the OS / shell / server / host (NOT the database).
impact_ok()   { printf '%s' "$(norm "$(val IMPACT)")" | grep -qE 'os|operatingsystem|shell|server|host|command'; }
# The fix: don't build a shell string - use an argument array / no shell.
fix_ok()      { printf '%s' "$(val FIX)" | grep -qiE 'arg(ument)? ?(array|list)|no.?shell|shell ?= ?false|exec(ve)?|parameter|list|do not build|don.t build|avoid shell'; }

flag_present()  { [ -f "$FLAG" ]; }
# The flag carries real command output (uid= from id), proving OS execution -
# an empty touch wouldn't contain it.
flag_executed() { grep -q 'uid=' "$FLAG" 2>/dev/null; }

section "1. Recon: understand the injection"
check "answers.txt: names a shell metacharacter that chains a command" \
  'operator_ok' "; ends a command and starts another; && | \$() backticks also work"
check "answers.txt: command injection gives code execution on the OS (not just the DB)" \
  'impact_ok' "unlike SQLi, you run commands on the operating system itself"

section "2. Exploit: run a command on the host"
check "/flag/solved exists (an injected command ran on the server)" \
  'flag_present' "inject e.g.  127.0.0.1; id > /flag/solved"
check "the flag holds real command output (uid= from id) - genuine OS execution" \
  'flag_executed' "capture a command's output into the flag, e.g. '; id > /flag/solved'"

section "3. Name the fix"
check "answers.txt: names the correct fix (argument array / no shell)" \
  'fix_ok' "subprocess.run([\"ping\",\"-c\",\"1\",host]) - input is never shell syntax"
