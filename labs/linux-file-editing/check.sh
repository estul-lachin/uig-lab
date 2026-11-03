# Checks for linux-file-editing (see templates/lab/check.sh for the rules).

W=/root/work
_is() { [ -f "$1" ] && [ "$(cat "$1")" = "$2" ]; }

section "1. nano"
check "nano-hello.txt says 'Hello from nano'" '_is $W/nano-hello.txt "Hello from nano"' \
  "nano nano-hello.txt, type the line, Ctrl+O Enter, Ctrl+X"
check "app.conf says production everywhere" '[ -f $W/app.conf ] && ! grep -q staging $W/app.conf && [ "$(grep -c production $W/app.conf)" = 3 ]' \
  "In nano: Ctrl+\\ (or Alt+R), staging, production, then A for all"
check "app.conf has nothing else changed" '[ -f $W/app.conf ] && ! grep -q staging $W/app.conf && [ "$(sed s/production/staging/g $W/app.conf | md5sum)" = "$(printf "%s\n" "# booking service" environment=staging db_host=db.staging.internal cache_host=cache.staging.internal log_level=info | md5sum)" ]' \
  "Only the word should change; Alt+U undoes a mistake"

section "2. vim"
check "case-notes.txt says 'investigation started'" '_is $W/case-notes.txt "investigation started"' \
  "vim case-notes.txt, i, type, Esc, :wq"
check "proxy.log has no 203.0.113.50 left" '[ -f $W/proxy.log ] && ! grep -q 203.0.113.50 $W/proxy.log' \
  ":%s/203.0.113.50/REDACTED/g (g also catches the second one on a line)"
check "All four occurrences became REDACTED" '[ "$(grep -o REDACTED $W/proxy.log | wc -l)" = 4 ]' \
  "Replace with the exact word REDACTED"
check "The other IP is untouched" 'grep -q REDACTED $W/proxy.log && [ "$(grep -c 198.51.100.7 $W/proxy.log)" = 1 ] && [ "$(wc -l < $W/proxy.log)" = 4 ]' \
  "Only 203.0.113.50 should change; :q! leaves without saving if it went wrong"

section "3. cat"
check "cat-made.txt has exactly the two lines" '_is $W/cat-made.txt "$(printf "written with cat\nappended with cat")"' \
  "cat > cat-made.txt, type, Ctrl+D; then cat >> cat-made.txt for the second line"
check "timeline.log is part1.log followed by part2.log" '[ -f $W/timeline.log ] && [ -f $W/part1.log ] && cat $W/part1.log $W/part2.log | cmp -s - $W/timeline.log' \
  "cat part1.log part2.log > timeline.log"

section "4. echo, printf, tee, >"
check "greeting.txt has exactly the two lines" '_is $W/greeting.txt "$(printf "Hello, World!\nAnother line.")"' \
  "echo ... > greeting.txt, then echo ... >> greeting.txt"
check "users.tsv uses real tab characters" '[ -f $W/users.tsv ] && cmp -s $W/users.tsv <(printf "user\tnora\nrole\tanalyst\n")' \
  "printf with \\t and \\n; cat -A shows tabs as ^I"
check "seen.txt has both lines" '_is $W/seen.txt "$(printf "to both\nnext line")"' "tee, then tee -a"
check "date.txt holds exactly one timestamp" '[ -f $W/date.txt ] && [ "$(wc -l < $W/date.txt)" = 1 ] && date -d "$(cat $W/date.txt)" >/dev/null' \
  "The last write must be a single > (it overwrites)"

section "5. Triage note"
T=$W/triage.txt
check "triage.txt starts with the header line" '[ -f $T ] && [ "$(head -n1 $T)" = "== processes ==" ]' "printf or echo the header with >"
check "It contains the process list" '[ -f $T ] && grep -q "sleep infinity" $T && grep -q "^USER\|^ *PID\|UID" $T' \
  "Append ps aux (or ps -ef) after the header with tee -a or >>"
