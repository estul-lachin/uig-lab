# Checks for systemd-services (see templates/lab/check.sh for the rules).
# systemd really runs here, so the checks ask systemctl, journalctl and /proc.

timeout 20 systemctl is-system-running --wait >/dev/null 2>&1 || true
U=heartbeat.service
_pid() { systemctl show -p MainPID --value "$1" 2>/dev/null; }
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }

section "1. The program"
H=/usr/local/bin/heartbeat.sh
check "heartbeat.sh is executable with a shebang" '[ -x $H ] && head -n1 $H | grep -q "^#!"' "chmod +x"
check "It prints a heartbeat line every INTERVAL seconds (default 5)" '[ -x $H ] && [ "$(INTERVAL=1 timeout 3.5 $H | grep -c heartbeat)" -ge 3 ]' \
  "while true; do echo \"heartbeat ...\"; sleep \"\${INTERVAL:-5}\"; done"

section "2. The unit"
F=/etc/systemd/system/$U
check "$F has a Description, ExecStart and an [Install] section" '[ -f $F ] && grep -q "^Description=" $F && grep -q "^ExecStart=$H" $F && grep -q "^WantedBy=multi-user.target" $F' \
  "[Unit], [Service] and [Install] sections"
check "systemd accepts it" '[ -f $F ] && ! systemd-analyze verify $F 2>&1 | grep -v "systemd-netlink-helper\|report.service" | grep -qi "error\|invalid\|unknown"' \
  "systemd-analyze verify $F"

section "3. Running, enabled, as its own user"
check "heartbeat is active" 'systemctl is-active -q $U' "systemctl daemon-reload, then systemctl start"
check "heartbeat is enabled" '[ "$(systemctl is-enabled $U 2>/dev/null)" = enabled ]' "systemctl enable (it creates the wants/ symlink)"
check "Its process runs as the user heartbeat" 'p=$(_pid $U); [ "${p:-0}" != 0 ] && [ "$(ps -o user= -p $p)" = heartbeat ]' \
  "A system user (useradd -r -s /usr/sbin/nologin heartbeat) and User= in [Service]"
check "Its output reaches the journal" 'journalctl -u $U --no-pager -q 2>/dev/null | grep -q heartbeat' "journalctl -u heartbeat"

section "4. Restart policy"
check "After a crash systemd starts it again" 'p=$(_pid $U); [ "${p:-0}" != 0 ] && kill -9 $p && sleep 2 && q=$(_pid $U) && [ "${q:-0}" != 0 ] && [ "$q" != "$p" ] && systemctl is-active -q $U' \
  "Restart=on-failure (a kill -9 is a failure)"

section "5. Drop-in override"
D=/etc/systemd/system/$U.d
check "A drop-in in $D sets INTERVAL=2" '[ -d $D ] && grep -rqs "Environment=.*INTERVAL=2" $D/*.conf' "systemctl edit heartbeat, or create $D/override.conf"
check "The main unit file doesn't mention INTERVAL" '[ -f $F ] && [ -d $D ] && ! grep -q INTERVAL $F' "Overrides belong in the drop-in"
check "The running process has INTERVAL=2" 'p=$(_pid $U); [ "${p:-0}" != 0 ] && tr "\0" "\n" < /proc/$p/environ | grep -qx INTERVAL=2' \
  "daemon-reload, then restart: a running process keeps its old environment"
check "/root/unit.txt is systemctl cat output, with the drop-in" '[ -f /root/unit.txt ] && grep -q "^# $F" /root/unit.txt && grep -q "^# $D/" /root/unit.txt' \
  "systemctl cat heartbeat > /root/unit.txt"

section "6. The failing unit"
check "report.service is active" 'systemctl is-active -q report.service' \
  "systemctl --failed, systemctl status report, journalctl -u report: then fix the unit, daemon-reload, restart"
check "FAILED_REASON names the missing file" '[ "$(_kv /root/answers.txt FAILED_REASON)" = /usr/local/bin/reprot.sh ]' "The path systemd couldn't execute"
check "It still runs the real script" 'grep -q "^ExecStart=/usr/local/bin/report.sh" /etc/systemd/system/report.service && journalctl -u report.service --no-pager -q | grep -q "report generated"' \
  "Fix the path in ExecStart; don't create a reprot.sh"

section "7. The backdoor service"
B=systemd-netlink-helper.service
check "BACKDOOR_UNIT is right" '[ "$(_kv /root/answers.txt BACKDOOR_UNIT)" = $B ]' \
  "Look at what each enabled service runs; systemd's own units come from packages (dpkg -S)"
check "BACKDOOR_TARGET is right" '[ "$(_kv /root/answers.txt BACKDOOR_TARGET)" = 203.0.113.50:4444 ]' "IP:PORT from its ExecStart"
check "It is stopped, disabled and deleted" '[ -f /root/answers.txt ] && [ ! -e /etc/systemd/system/$B ] && [ ! -L /etc/systemd/system/multi-user.target.wants/$B ] && ! systemctl is-active -q $B' \
  "systemctl disable --now, remove the file, daemon-reload"
check "systemd has forgotten it" '[ -f /root/answers.txt ] && [ "$(systemctl show -p LoadState --value $B)" = not-found ]' "systemctl daemon-reload"
check "No process still connects to 203.0.113.50" '[ -f /root/answers.txt ] && ! pgrep -af "203.0.113.50" >/dev/null' "Stopping the unit kills its processes"
