# Checks for bash-loops (see templates/lab/check.sh for the rules).
# The checks run your scripts on prepared input, including the awkward cases.

D=/root/scripts
T=/tmp/loops-test
_prep() {
  rm -rf $T; mkdir -p $T/logs $T/empty
  printf '1\n2\n3\n' > $T/logs/app.log
  printf 'only\n' > "$T/logs/with space.log"
  printf 'x\n' > $T/logs/ignore.txt
}

section "1. Count lines per file (linecount.sh)"
C=$D/linecount.sh
check "linecount.sh is executable and uses a for loop" '[ -x $C ] && grep -Eq "^[[:space:]]*for " $C' "for f in *.log; do ...; done"
check "It prints 'name: N' for every .log file" '[ -x $C ] && _prep && [ "$(cd $T/logs && "$C" | sort)" = "$(printf "app.log: 3\nwith space.log: 1")" ]' \
  "Quote \"\$f\"; count with wc -l < \"\$f\" so the name isn't repeated"
check "In a directory without .log files it prints nothing" '[ -x $C ] && _prep && [ -z "$(cd $T/empty && "$C" 2>&1)" ]' \
  "An unmatched glob stays literally *.log; use shopt -s nullglob or [ -e \"\$f\" ] || continue"

section "2. Safe line-by-line read (numberlines.sh)"
N=$D/numberlines.sh
check "numberlines.sh uses while IFS= read -r" '[ -x $N ] && grep -q "while IFS= read -r" $N' "while IFS= read -r line; do ...; done < \"\$1\""
check "It numbers lines and keeps spaces and backslashes" '[ -x $N ] && [ "$("$N" /root/data/sample.txt | head -n 2)" = "$(printf "1:   indented line\n2: path C:\\\\temp\\\\new")" ]' \
  "Format: N: line. Without IFS= the leading spaces vanish; without -r the backslashes do"
check "It keeps the empty line and the last line without a newline" '[ -x $N ] && [ "$("$N" /root/data/sample.txt | tail -n 2)" = "$(printf "3: \n4: last line without newline")" ]' \
  "read fails on the unterminated last line; add || [ -n \"\$line\" ] to the loop condition"

section "3. Numeric for loop (squares.sh)"
S=$D/squares.sh
check "squares.sh prints the squares of 1..10" '[ -x $S ] && [ "$("$S")" = "$(printf "%s\n" 1 4 9 16 25 36 49 64 81 100)" ]' "for (( i = 1; i <= n; i++ )); do echo \$(( i * i )); done"
check "squares.sh 3 prints 1 4 9" '[ -x $S ] && [ "$("$S" 3)" = "$(printf "1\n4\n9")" ]' \
  "{1..\$n} doesn't expand a variable; use the C-style for with n=\${1:-10}"

section "4. Process substitution (new-accounts.sh)"
A=$D/new-accounts.sh
check "new-accounts.sh uses <( ) process substitution" '[ -x $A ] && grep -q "<(" $A' "comm -13 <(sort ...) <(sort ...)"
check "It prints exactly the accounts added since the baseline" '[ -x $A ] && [ "$("$A")" = "$(printf "kthreadd2\nsvc-sync")" ]' \
  "Compare sorted /root/data/baseline-users.txt with the sorted names from /etc/passwd; print only the new ones, sorted"
check "It follows the live system" '[ -x $A ] && useradd -M lab-probe-user && out=$("$A"); userdel lab-probe-user; echo "$out" | grep -qx lab-probe-user' \
  "Read /etc/passwd each time; don't hard-code the names"
rm -rf $T
