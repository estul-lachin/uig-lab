# Checks for logs-journald (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
A=/root/answers.txt
IB=9f8e7d6c5b4a43219876fedcba012345
_same() { [ -s "$1" ] && [ "$(grep -v "^-- " "$1")" = "$(eval "$2" 2>/dev/null | grep -v "^-- ")" ]; }

section "1. Boots"
check "/root/boots.txt is the boot list" '_same /root/boots.txt "journalctl --list-boots --no-pager"' "journalctl --list-boots"
check "INCIDENT_BOOT is the boot of 2026-10-30" '[ "$(_kv $A INCIDENT_BOOT)" = $IB ]' "The BOOT ID column"

section "2. Kernel messages of that boot"
check "/root/boot.log holds its kernel messages" '_same /root/boot.log "journalctl -b $IB -k --no-pager"' \
  "journalctl -b <boot id> -k; -b 0 means the container's own boot, which isn't in this journal"
check "KILLED_PROCESS is right" '[ "$(_kv $A KILLED_PROCESS)" = kworkerds ]' "The OOM killer names the process it killed"

section "3. One unit, one time window"
check "/root/unit.log holds ssh.service from 02:14 to 02:16 on 2026-10-30" '_same /root/unit.log "journalctl -u ssh.service --since \"2026-10-30 02:14:00\" --until \"2026-10-30 02:16:00\" --no-pager"' \
  "journalctl -u ssh.service --since ... --until ... --no-pager"
check "ATTACKER_IP is right" '[ "$(_kv $A ATTACKER_IP)" = 203.0.113.50 ]' "Where do the failures come from?"
check "FAILED_COUNT is right" '[ "$(_kv $A FAILED_COUNT)" = 13 ]' "Count every Failed password line in that window, for any user"
check "BREACHED_USER is right" '[ "$(_kv $A BREACHED_USER)" = deploy ]' "Which Accepted login comes from the same address?"
check "LOGIN_TIME is right" '[ "$(_kv $A LOGIN_TIME)" = 02:14:37 ]' "HH:MM:SS of that Accepted line"

section "4. Priority and grep"
check "ERR_ENTRIES counts entries of priority err or worse in the whole journal" '[ "$(_kv $A ERR_ENTRIES)" = 4 ]' "journalctl -p err --no-pager -q | wc -l"
check "ROOT_COMMAND is what the intruder ran through sudo" '[ "$(_kv $A ROOT_COMMAND)" = /usr/bin/bash ]' "journalctl -g COMMAND="

section "5. Rotated plain-text logs"
check "AUTH_FAILED_ALL counts failed passwords in auth.log and all its rotations" '[ "$(_kv $A AUTH_FAILED_ALL)" = 6 ]' \
  "zgrep reads plain and .gz files alike: zgrep -h \"Failed password\" /var/log/auth.log*"
check "AUTH_OLDEST_ATTACKER is the source in the oldest rotation" '[ "$(_kv $A AUTH_OLDEST_ATTACKER)" = 192.0.2.77 ]' "The highest number is the oldest"

section "6. logrotate config"
C=/etc/logrotate.d/orders
check "$C exists and names /var/log/orders/*.log" '[ -f $C ] && grep -q "/var/log/orders/\*\.log" $C' "One block: path { options }"
check "It rotates weekly, keeps 4, compresses, and uses copytruncate" '[ -f $C ] && for o in weekly "rotate 4" compress copytruncate; do grep -Eq "^[[:space:]]*$o[[:space:]]*$" $C || exit 1; done' \
  "One option per line"
_lrsim() {
  local d=/tmp/lr-sim; rm -rf $d; mkdir -p $d
  seq 1 50 > $d/orders.log; local ino; ino=$(stat -c %i $d/orders.log)
  sed "s|/var/log/orders/\*\.log|$d/*.log|" $C > $d/conf
  logrotate -f -s $d/state $d/conf >/dev/null 2>&1 || return 1
  [ -f $d/orders.log.1.gz ] && [ ! -s $d/orders.log ] && [ "$(stat -c %i $d/orders.log)" = "$ino" ] || return 1
  for i in 2 3 4 5 6; do echo "line $i" >> $d/orders.log; logrotate -f -s $d/state $d/conf >/dev/null 2>&1 || return 1; done
  [ "$(ls $d | grep -c "^orders\.log\.[0-9]")" = 4 ]
}
check "A forced rotation on a copy behaves as configured" '[ -f $C ] && _lrsim' \
  "Expected: orders.log.1.gz appears, orders.log is emptied in place (same inode), and only 4 rotations are kept"
rm -rf /tmp/lr-sim

section "7. Dry run"
check "/root/lr.log holds the logrotate -d output for the config" '[ -f /root/lr.log ] && grep -q "rotating pattern: /var/log/orders/\*\.log" /root/lr.log' \
  "logrotate -d writes to stderr: logrotate -d $C 2> /root/lr.log (or > /root/lr.log 2>&1)"
check "The dry run changed nothing" '[ "$(wc -l < /var/log/orders/orders.log)" = 500 ] && [ ! -e /var/log/orders/orders.log.1.gz ]' "-d only reports"
