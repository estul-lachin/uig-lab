# Checks for memory-swap (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
A=/root/answers.txt
HOG=$(cat /run/.lab-hog-pid 2>/dev/null)

section "1. free"
check "/root/free.txt is free -h output" 'grep -q "^Mem:" /root/free.txt 2>/dev/null && grep -q "^Swap:" /root/free.txt && grep -Eq "[0-9.]+(Gi|Mi)" /root/free.txt' "free -h > /root/free.txt"
check "AVAILABLE_IS explains the available column" '[ "$(_kv $A AVAILABLE_IS | tr A-Z a-z)" = estimate ]' \
  "available is the kernel's estimate of what can be used without swapping (free plus reclaimable cache): write estimate"

section "2. /proc/meminfo"
M=/root/mem_highlights.txt
check "mem_highlights.txt holds exactly MemTotal, MemAvailable and Buffers" '[ "$(cut -d: -f1 $M 2>/dev/null | sort | paste -sd,)" = Buffers,MemAvailable,MemTotal ]' \
  "grep -E \"^(MemTotal|MemAvailable|Buffers):\" /proc/meminfo"
check "MemTotal matches the kernel" '[ "$(grep ^MemTotal: $M 2>/dev/null | tr -s " ")" = "$(grep ^MemTotal: /proc/meminfo | tr -s " ")" ]' "Copy the lines as they are"

section "3. Top memory consumers"
T=/root/topmem.txt
_rsscol() { head -n1 $T | tr -s " " "\n" | grep -v "^$" | grep -nx RSS | cut -d: -f1; }
check "topmem.txt has a header with RSS and at most 10 processes" 'c=$(_rsscol); [ -n "$c" ] && n=$(($(wc -l < $T) - 1)) && [ $n -ge 3 ] && [ $n -le 10 ]' \
  "ps -eo pid,comm,rss,args --sort=-rss | head -n 11"
check "They are sorted by RSS, largest first" 'c=$(_rsscol); [ -n "$c" ] && tail -n +2 $T | awk -v c="$c" "{print \$c}" | sort -nrc' "--sort=-rss"

section "4. Swappiness"
check "/root/swappiness.txt holds vm.swappiness" '[ "$(tr -d "[:space:]" < /root/swappiness.txt 2>/dev/null)" = "$(cat /proc/sys/vm/swappiness)" ]' "cat /proc/sys/vm/swappiness"
check "SWAP_TOTAL_MB is the swap free reports" 'v=$(_kv $A SWAP_TOTAL_MB); [ -n "$v" ] && [ "$v" = "$(free -m | awk "/^Swap:/ {print \$2}")" ]' "free -m: the total of the Swap: row (0 is a valid answer)"

section "5. The container's real limit"
check "HOST_TOTAL_MB is what free and /proc/meminfo report" 'v=$(_kv $A HOST_TOTAL_MB); [ -n "$v" ] && [ "$v" = "$(free -m | awk "/^Mem:/ {print \$2}")" ]' "free -m, total of the Mem: row"
check "LIMIT_MB is the container's cgroup limit" '[ "$(_kv $A LIMIT_MB)" = $(( $(cat /sys/fs/cgroup/memory.max) / 1048576 )) ]' "cat /sys/fs/cgroup/memory.max (bytes)"

section "6. The disguised process"
check "HOG_PID is the biggest process" '[ -n "$HOG" ] && [ "$(_kv $A HOG_PID)" = "$HOG" ]' "The first line of your top list"
check "HOG_DISGUISE is the name ps shows" '[ "$(_kv $A HOG_DISGUISE)" = "[kswapd1]" ]' "ps -o args="
check "HOG_PROGRAM is the program really running" '[ "$(_kv $A HOG_PROGRAM)" = /usr/bin/bash ]' "readlink /proc/<pid>/exe (a real kernel thread has none)"
check "HOG_SCRIPT is the file it was reading its code from" '[ "$(_kv $A HOG_SCRIPT)" = /usr/local/lib/.cache/kmon ]' "ls -l /proc/<pid>/fd"
check "HOG_RSS_MB is about its RSS" 'v=$(_kv $A HOG_RSS_MB); r=$(( $(cat /run/.lab-hog-rss 2>/dev/null || echo 0) / 1024 )); [ -n "$v" ] && [ $r -gt 0 ] && [ $((v * 100)) -ge $((r * 85)) ] && [ $((v * 100)) -le $((r * 115)) ]' "RSS is in KiB in ps; divide by 1024"
check "It is gone, and the container's usage dropped" '[ -n "$HOG" ] && [ -f $A ] && ! kill -0 $HOG 2>/dev/null && [ $(cat /sys/fs/cgroup/memory.current) -lt 104857600 ]' \
  "kill <pid>; memory.current shows the container's usage"
check "Its script is deleted" '[ -f $A ] && [ ! -e /usr/local/lib/.cache/kmon ]' "rm it"
