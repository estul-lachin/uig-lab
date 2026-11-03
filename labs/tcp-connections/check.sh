# Checks for tcp-connections (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_listening() { [ -n "$(ss -Htln "sport = :$1")" ]; }
_est() { ss -Htn state established "( sport = :$1 or dport = :$1 )" | wc -l; }

section "1. Listening sockets"
check "/root/listen.txt holds ss output" '[ -f /root/listen.txt ] && grep -q LISTEN /root/listen.txt' "ss -tlnp > /root/listen.txt"
check "It is numeric and shows the processes" 'grep -q "users:((" /root/listen.txt && grep -Eq ":[0-9]+ " /root/listen.txt' \
  "-n keeps port numbers, -p adds the owning process"

section "2. A listener that survives"
check "Something listens on TCP 9001" '_listening 9001' \
  "nohup setsid ncat -lk -p 9001 </dev/null >/dev/null 2>&1 & disown"
check "It is ncat" 'ss -Htlnp "sport = :9001" | grep -q "\"ncat\""' "Start it with ncat"

section "3. Send a line"
check "/root/recv.txt holds the message" '[ -f /root/recv.txt ] && grep -qx "case 4471 opened" /root/recv.txt' \
  "One-shot listener on 9002 writing to /root/recv.txt, then echo ... | ncat --send-only 127.0.0.1 9002"

section "4. Hold a connection open"
check "Listener on 9003 is up" '_listening 9003' "ncat -lk --no-shutdown -p 9003, daemonised"
check "A connection to 9003 is ESTABLISHED" '[ "$(_est 9003)" -ge 2 ]' "Connect a client with ncat --no-shutdown, daemonised too"
check "/root/est_count.txt matches the live count" 'v=$(tr -d "[:space:]" < /root/est_count.txt); [ -n "$v" ] && [ "$v" = "$(_est 9003)" ]' \
  "ss -H -tn state established \"( sport = :9003 or dport = :9003 )\" | wc -l > /root/est_count.txt"

section "5. The odd listener"
F=/root/findings.txt
check "ODD_PORT is right" '[ "$(_kv $F ODD_PORT)" = 31337 ]' "ss -tlnp: which port isn't one you started?"
check "ODD_PROCESS is right" '[ "$(_kv $F ODD_PROCESS)" = kupdated ]' "The name inside users:((\"...\""
check "ODD_PATH is the program's full path" '[ "$(_kv $F ODD_PATH)" = /usr/local/sbin/kupdated ]' \
  "ls -l /proc/<pid>/exe, with the pid from ss -p"
check "Nothing listens on 31337 any more" '[ -f $F ] && ! _listening 31337' "kill <pid>"
check "Your own listeners are still up" '_listening 9001 && _listening 9003' "Kill only the odd one"
