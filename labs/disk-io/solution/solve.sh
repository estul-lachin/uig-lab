# Reference solution for disk-io.
set -euo pipefail
A=/root/answers.txt

# 1. Baseline
iostat -xz 1 3 > /root/iostat.txt

# 2-3. Counters around a 200 MiB write that must reach the disk
cat /proc/diskstats > /root/diskstats.before
dd if=/dev/zero of=/tmp/io.bin bs=1M count=200 conv=fsync 2> /root/dd.txt
cat /proc/diskstats > /root/diskstats.after
secs=$(sed -n 's/.* copied, \([0-9.]*\) s,.*/\1/p' /root/dd.txt)
read -r disk sectors < <(awk 'NR == FNR {b[$3] = $10; next} ($3 in b) {print $3, $10 - b[$3]}' \
  /root/diskstats.before /root/diskstats.after | sort -k2,2n | tail -n1)
mb=$(( sectors * 512 / 1048576 ))

# 4. Busiest device in the saved report
busy=$(awk '/^Device/ {r = 1; next} r && NF > 1 && $1 != "avg-cpu:" { if (d == "" || $NF + 0 > m) { m = $NF + 0; d = $1 } } /^$/ {r = 0} END {print d}' /root/iostat.txt)
echo "$busy" > /root/busy.txt

# 5. The hidden writer: the process with the most written bytes, its file and its parent
for _ in 1 2 3 4 5; do pid=$(pgrep -x kflushd | head -n1 || true); [ -n "$pid" ] && break; sleep 1; done
name=$(ps -o comm= -p "$pid")
file=$(readlink "/proc/$pid/fd/1")
ppid=$(ps -o ppid= -p "$pid" | tr -d ' ')
parent=$(ps -o args= -p "$ppid" | awk '{print $NF}')
kill "$ppid"; sleep 1; pkill -x kflushd || true
rm -f "$file" /usr/local/lib/.sys/kflushd "$parent"

{
  echo "DD_SECONDS=$secs"
  echo "DISK=$disk"
  echo "WRITTEN_MB=$mb"
  echo "WRITER_NAME=$name"
  echo "WRITER_FILE=$file"
  echo "WRITER_PARENT=$parent"
} > "$A"
