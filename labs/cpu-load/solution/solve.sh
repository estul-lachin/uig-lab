# Reference solution for cpu-load.
set -euo pipefail
A=/root/answers.txt

# 1. Load against the budget
awk '{print $1, $2, $3}' /proc/loadavg > /root/load.txt
read -r quota period < /sys/fs/cgroup/cpu.max

# 2. vmstat
vmstat 1 5 > /root/vmstat.txt

# 3. Load of our own, caught by top, then stopped
yes > /dev/null &
ypid=$!
sleep 1
top -b -n 1 > /root/top.txt
kill "$ypid"; wait "$ypid" 2>/dev/null || true

# 4. Per CPU
mpstat -P ALL 1 1 > /root/mpstat.txt

# 5. The miner: wait for a live instance, then trace it to its parent
for _ in $(seq 1 20); do pid=$(pgrep -x kdevtmpfsi | head -n1 || true); [ -n "$pid" ] && break; sleep 0.2; done
path=$(readlink "/proc/$pid/exe")
# Walk up the PPIDs past helpers like timeout until we reach the shell loop.
ppid=$pid
while :; do
  ppid=$(ps -o ppid= -p "$ppid" | tr -d ' ')
  case "$(ps -o args= -p "$ppid")" in "/bin/sh "*) break ;; esac
  [ "$ppid" -le 1 ] && break
done
parent=$(ps -o args= -p "$ppid" | awk '{print $NF}')
is=$(for f in /usr/bin/*; do [ -f "$f" ] && cmp -s "$f" "$path" && basename "$f" && break; done)
kill "$ppid"
sleep 1
pkill -x kdevtmpfsi || true
rm -f "$path" "$parent"

{
  echo "VISIBLE_CPUS=$(nproc)"
  echo "CPU_LIMIT=$(( quota / period ))"
  echo "VMSTAT_RUNQ_COLUMN=r"
  echo "VMSTAT_STEAL_COLUMN=st"
  echo "MINER_NAME=kdevtmpfsi"
  echo "MINER_PATH=$path"
  echo "MINER_IS=$is"
  echo "MINER_PARENT=$parent"
} > "$A"
