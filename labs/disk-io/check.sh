# Checks for disk-io (see templates/lab/check.sh for the rules).
# Device names differ between machines, so the checks recompute your answers from your own files.

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
A=/root/answers.txt

section "1. iostat baseline"
check "/root/iostat.txt holds 3 extended reports" '[ "$(grep -c "^Device" /root/iostat.txt 2>/dev/null)" = 3 ] && grep -q "%util" /root/iostat.txt' \
  "iostat -xz 1 3 > /root/iostat.txt (extended stats, 1-second interval, 3 reports)"

section "2. Write load"
check "/root/dd.txt holds dd's summary line" 'grep -Eq "^209715200 bytes .* copied, .* s, " /root/dd.txt 2>/dev/null' \
  "dd reports on stderr: dd ... 2> /root/dd.txt; 200 blocks of 1M"
check "/tmp/io.bin is 200 MiB" '[ "$(stat -c %s /tmp/io.bin 2>/dev/null)" = 209715200 ]' "bs=1M count=200"
check "DD_SECONDS matches dd's own report" 'v=$(_kv $A DD_SECONDS); s=$(sed -n "s/.* copied, \([0-9.]*\) s,.*/\1/p" /root/dd.txt 2>/dev/null); [ -n "$v" ] && [ "$v" = "$s" ]' \
  "The number before \" s,\" in dd.txt"

section "3. Disk counters around the load"
check "/root/diskstats.before and .after are /proc/diskstats copies" 'for f in /root/diskstats.before /root/diskstats.after; do [ "$(awk "NF >= 14" $f 2>/dev/null | wc -l)" -gt 0 ] || exit 1; done && ! cmp -s /root/diskstats.before /root/diskstats.after' \
  "cat /proc/diskstats > /root/diskstats.before, run dd, then the same into .after"
check "DISK names a device that wrote at least 200 MiB in between" 'd=$(_kv $A DISK); [ -n "$d" ] && b=$(awk -v d="$d" "\$3 == d {print \$10}" /root/diskstats.before) && a=$(awk -v d="$d" "\$3 == d {print \$10}" /root/diskstats.after) && [ -n "$b" ] && [ $(( (a - b) * 512 )) -ge 209715200 ]' \
  "Field 10 is sectors written (512 bytes each); compare each disk's before and after"
check "WRITTEN_MB is that difference in MiB (±1)" 'd=$(_kv $A DISK); w=$(_kv $A WRITTEN_MB); b=$(awk -v d="$d" "\$3 == d {print \$10}" /root/diskstats.before) && a=$(awk -v d="$d" "\$3 == d {print \$10}" /root/diskstats.after) && [ -n "$w" ] && x=$(( (a - b) * 512 / 1048576 )) && [ $(( w - x )) -le 1 ] && [ $(( x - w )) -le 1 ]' \
  "(after - before) * 512 / 1048576, rounded down"

section "4. Busiest device"
_busiest() { awk '/^Device/ {inrep = 1; next} inrep && NF > 1 && $1 != "avg-cpu:" { if (dev == "" || $NF + 0 > max) { max = $NF + 0; dev = $1 } } /^$/ {inrep = 0} END {print dev}' /root/iostat.txt; }
check "/root/busy.txt names the device with the highest %util in your iostat.txt" '[ -s /root/iostat.txt ] && [ -n "$(_busiest)" ] && [ "$(tr -d "[:space:]" < /root/busy.txt 2>/dev/null)" = "$(_busiest)" ]' \
  "%util is the last column; compare all device lines with awk or sort -k"

section "5. The hidden writer"
check "WRITER_NAME is the process doing the writes" '[ "$(_kv $A WRITER_NAME)" = kflushd ]' "pidstat -d 1 5: the kB_wr/s column"
check "WRITER_FILE is the file it writes" '[ "$(_kv $A WRITER_FILE)" = /var/tmp/.cache/blob ]' "ls -l /proc/<pid>/fd while it runs"
check "WRITER_PARENT is the program that keeps restarting it" '[ "$(_kv $A WRITER_PARENT)" = /usr/local/lib/.sys/flush-loop ]' "ps -o ppid= -p <pid>, then ps -o args= -p <ppid>"
check "It stays stopped" '[ -f $A ] && ! pgrep -x kflushd >/dev/null && sleep 3 && ! pgrep -x kflushd >/dev/null && ! pgrep -f "^/bin/sh /usr/local/lib/.sys/flush-loop" >/dev/null' \
  "Killing only kflushd isn't enough: its parent loop starts it again"
check "Its file and programs are gone" '[ -f $A ] && [ ! -e /var/tmp/.cache/blob ] && [ ! -e /usr/local/lib/.sys/kflushd ] && [ ! -e /usr/local/lib/.sys/flush-loop ]' "rm them once nothing runs"
