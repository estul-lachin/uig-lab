# Reference solution for memory-swap.
set -euo pipefail
A=/root/answers.txt

# Right after a reset the big process is still filling its memory; wait until it settles.
for _ in $(seq 1 30); do
  [ "$(ps -eo rss= --sort=-rss | head -n1)" -gt 133000 ] && break
  sleep 1
done

# 1-4. The usual views
free -h > /root/free.txt
grep -E '^(MemTotal|MemAvailable|Buffers):' /proc/meminfo > /root/mem_highlights.txt
ps -eo pid,comm,rss,args --sort=-rss | head -n 11 > /root/topmem.txt
cat /proc/sys/vm/swappiness > /root/swappiness.txt

# 6. The biggest process and what it really is
pid=$(ps -eo pid=,rss= --sort=-rss | awk 'NR == 1 {print $1}')
disguise=$(ps -o args= -p "$pid")
program=$(readlink "/proc/$pid/exe")
script=$(readlink "/proc/$pid/fd/0")
rss_mb=$(( $(ps -o rss= -p "$pid") / 1024 ))
{
  echo "AVAILABLE_IS=estimate"
  echo "SWAP_TOTAL_MB=$(free -m | awk '/^Swap:/ {print $2}')"
  echo "HOST_TOTAL_MB=$(free -m | awk '/^Mem:/ {print $2}')"
  echo "LIMIT_MB=$(( $(cat /sys/fs/cgroup/memory.max) / 1048576 ))"
  echo "HOG_PID=$pid"
  echo "HOG_DISGUISE=$disguise"
  echo "HOG_PROGRAM=$program"
  echo "HOG_SCRIPT=$script"
  echo "HOG_RSS_MB=$rss_mb"
} > "$A"
kill "$pid"
rm -f "$script"
sleep 2
