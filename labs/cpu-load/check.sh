# Checks for cpu-load (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
A=/root/answers.txt

section "1. Load average and the CPU budget"
check "/root/load.txt holds the three load averages" 'grep -Eqx "[0-9]+\.[0-9]{2} [0-9]+\.[0-9]{2} [0-9]+\.[0-9]{2}" /root/load.txt 2>/dev/null' \
  "cut -d\" \" -f1-3 /proc/loadavg > /root/load.txt"
check "VISIBLE_CPUS is what nproc says" '[ "$(_kv $A VISIBLE_CPUS)" = "$(nproc)" ]' "nproc"
check "CPU_LIMIT is the container's cgroup CPU limit" 'read -r q p < /sys/fs/cgroup/cpu.max; [ "$(_kv $A CPU_LIMIT)" = $(( q / p )) ]' \
  "cat /sys/fs/cgroup/cpu.max: quota and period in microseconds; quota / period = CPUs"

section "2. vmstat"
V=/root/vmstat.txt
check "/root/vmstat.txt holds 5 samples" '[ "$(grep -cE "^ *[0-9]+ +[0-9]+ " $V 2>/dev/null)" = 5 ] && grep -q " r  *b " $V' "vmstat 1 5 > /root/vmstat.txt"
check "VMSTAT_RUNQ_COLUMN names the run-queue column" '[ "$(_kv $A VMSTAT_RUNQ_COLUMN)" = r ]' "The first column under procs"
check "VMSTAT_STEAL_COLUMN names the stolen-time column" '[ "$(_kv $A VMSTAT_STEAL_COLUMN)" = st ]' "Last of the cpu columns; time the hypervisor gave to someone else"

section "3. Load you made yourself"
check "/root/top.txt is a batch top snapshot showing yes" 'grep -q "^top - " /root/top.txt 2>/dev/null && grep -Eq " yes *$" /root/top.txt' \
  "yes > /dev/null & then top -b -n 1 > /root/top.txt"
check "Your yes is stopped again" 'grep -Eq " yes *$" /root/top.txt 2>/dev/null && ! pgrep -x yes >/dev/null' "kill %1, or kill <pid>"

section "4. mpstat per CPU"
M=/root/mpstat.txt
check "/root/mpstat.txt has an all line and one line per CPU" '[ -f $M ] && grep -Eq "^Average: +all " $M && [ "$(grep -cE "^Average: +[0-9]+ " $M)" = "$(nproc)" ]' "mpstat -P ALL 1 1 > /root/mpstat.txt"

section "5. The miner"
check "MINER_NAME is the process name" '[ "$(_kv $A MINER_NAME)" = kdevtmpfsi ]' "top -b -n 1 -o %CPU, or pidstat -u 1 5"
check "MINER_PATH is its program file" '[ "$(_kv $A MINER_PATH)" = /usr/local/lib/.x/kdevtmpfsi ]' "readlink /proc/<pid>/exe; the PID changes every second"
check "MINER_IS names the standard program it is a copy of" '[ "$(_kv $A MINER_IS)" = yes ]' "cmp it with programs in /usr/bin, or run it with --version"
check "MINER_PARENT is the loop that restarts it" '[ "$(_kv $A MINER_PARENT)" = /usr/local/lib/.x/kinsing ]' "ps -o ppid= -p <pid>, then ps -o args= -p <ppid>"
check "It stays gone" '[ -f $A ] && ! pgrep -x kdevtmpfsi >/dev/null && sleep 2 && ! pgrep -x kdevtmpfsi >/dev/null && ! pgrep -f "^/bin/sh /usr/local/lib/.x/kinsing" >/dev/null' \
  "Stop the parent loop first; killing the child alone just gives it a new PID"
check "Its files are deleted" '[ -f $A ] && [ ! -e /usr/local/lib/.x/kdevtmpfsi ] && [ ! -e /usr/local/lib/.x/kinsing ]' "rm both"
