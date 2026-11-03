# Checks for sysctl-tuning (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
A=/root/answers.txt
H=/etc/sysctl.d/90-hardening.conf

# The order sysctl --system applies files: by file name across these directories (the first
# directory holding a name wins), then /etc/sysctl.conf last. The last assignment of a key wins.
_files() {
  local d f seen=" "
  for d in /etc/sysctl.d /run/sysctl.d /usr/local/lib/sysctl.d /usr/lib/sysctl.d /lib/sysctl.d; do
    for f in "$d"/*.conf; do
      [ -f "$f" ] || continue
      case "$seen" in *" ${f##*/} "*) continue ;; esac
      seen="$seen${f##*/} "; printf '%s\t%s\n' "${f##*/}" "$f"
    done
  done | sort | cut -f2
  [ -f /etc/sysctl.conf ] && echo /etc/sysctl.conf
}
_effective() {
  local f
  _files | while read -r f; do sed -e "s/[#;].*//" "$f" | awk -F= -v f="$f" 'NF == 2 { gsub(/[ \t]/, "", $1); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $1 "\t" $2 "\t" f }'; done \
    | awk -F'\t' -v k="$1" '$1 == k { v = $2; src = $3 } END { if (v != "") print v "\t" src }'
}
_eff_value() { _effective "$1" | cut -f1; }

section "1. Reading parameters"
check "/root/swap.txt holds vm.swappiness as sysctl prints it" '[ "$(cat /root/swap.txt 2>/dev/null)" = "$(sysctl vm.swappiness)" ]' "sysctl vm.swappiness > /root/swap.txt"
check "SWAPPINESS_PATH is the /proc/sys file behind it" '[ "$(_kv $A SWAPPINESS_PATH)" = /proc/sys/vm/swappiness ]' "Dots in the name become slashes under /proc/sys"

section "2. Auditing the live network settings"
check "IP_FORWARD_NOW is the live value" '[ "$(_kv $A IP_FORWARD_NOW)" = "$(sysctl -n net.ipv4.ip_forward)" ]' "sysctl -n net.ipv4.ip_forward"
check "UNSAFE_NOW lists the three live settings that should be 0" '[ "$(_kv $A UNSAFE_NOW | tr , "\n" | sort | paste -sd, -)" = net.ipv4.conf.all.accept_redirects,net.ipv4.conf.all.send_redirects,net.ipv4.ip_forward ]' \
  "Look at ip_forward and the conf.all.*redirects settings; comma-separated full names"

section "3. Trying a runtime change"
check "/root/tune.cmd holds the runtime commands" 'grep -Eq "sysctl -w +vm\.swappiness=10" /root/tune.cmd && grep -Eq "sysctl -w +net\.ipv4\.ip_forward=0" /root/tune.cmd' \
  "sysctl -w vm.swappiness=10 and sysctl -w net.ipv4.ip_forward=0, one per line"
check "RUNTIME_ERROR is what the container answered" '[ -f $A ] && grep -Eqi "^RUNTIME_ERROR=.*(read-only|permission denied)" $A' \
  "Run one of them and copy the reason sysctl gives"

section "4. Hardening drop-in"
_keys="vm.swappiness net.ipv4.ip_forward net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.send_redirects net.ipv4.conf.all.rp_filter net.ipv4.tcp_syncookies"
check "$H sets all six values" '[ -f $H ] && for kv in vm.swappiness=10 net.ipv4.ip_forward=0 net.ipv4.conf.all.accept_redirects=0 net.ipv4.conf.all.send_redirects=0 net.ipv4.conf.all.rp_filter=1 net.ipv4.tcp_syncookies=1; do sed "s/[[:space:]]//g" $H | grep -qx "$kv" || exit 1; done' \
  "key = value, one per line"
check "sysctl knows every key in it" '[ -f $H ] && ! sysctl -p $H 2>&1 | grep -qi "cannot stat\|unknown key\|invalid"' \
  "sysctl -p $H: a typo shows as cannot stat; read-only errors are expected here"
check "/root/reload.txt holds sysctl -p output, errors included" '[ -f /root/reload.txt ] && grep -qi "read-only\|permission denied" /root/reload.txt && grep -q "vm.swappiness" /root/reload.txt' \
  "Errors go to stderr: sysctl -p $H > /root/reload.txt 2>&1"

section "5. Which file wins"
check "EFFECTIVE_IP_FORWARD_BEFORE is what a reboot would have applied before the fix" '[ "$(_kv $A EFFECTIVE_IP_FORWARD_BEFORE)" = 1 ]' \
  "Files are applied in file-name order; the last assignment wins"
check "OVERRIDE_FILE names the file that beat your drop-in" '[ "$(_kv $A OVERRIDE_FILE)" = /etc/sysctl.d/99-zz-vpn.conf ]' "Compare names with ls /etc/sysctl.d: which sorts after 90-hardening.conf?"
check "After the fix, every hardening value wins at boot" '[ -f $H ] && [ -f $A ] && [ "$(_eff_value net.ipv4.ip_forward)" = 0 ] && [ "$(_eff_value net.ipv4.conf.all.accept_redirects)" = 0 ] && [ "$(_eff_value net.ipv4.conf.all.send_redirects)" = 0 ] && [ "$(_eff_value vm.swappiness)" = 10 ]' \
  "Remove the overriding file (and check /etc/sysctl.conf, which is applied last)"
check "Your drop-in is the file that sets them" '[ "$(_effective net.ipv4.ip_forward | cut -f2)" = $H ]' "Nothing later may repeat the key"
