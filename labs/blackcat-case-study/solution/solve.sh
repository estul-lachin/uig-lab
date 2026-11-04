# Reference solution for blackcat-case-study.
set -eu   # no pipefail: several pipes end in head -n1, which closes them early
umask 022
S=$(pwd)
cd /root/case

ticket=$(awk -F, '$4 == "mfa_reset" && $5 == "no" {print $1}' helpdesk-tickets.csv | head -n1)
user=$(awk -F, -v t="$ticket" '$1 == t {print $3}' helpdesk-tickets.csv)
ttime=$(awk -F, -v t="$ticket" '$1 == t {print $2}' helpdesk-tickets.csv)
ip=$(jq -r --arg u "$user" --arg t "$ttime" 'select(.user == $u and .time > $t and .result == "success") | .ip' idp-signins.jsonl | head -n1)
rogue=$(jq -r 'select(.image | test("AnyDesk|Splashtop|ScreenConnect"; "i")) | .host' edr-process.jsonl | sort -u \
  | while read -r h; do grep -q "^$h,AnyDesk$" approved-remote-tools.csv || echo "$h"; done | head -n1)
admin=$(jq -r 'select(.image | test("psexec"; "i")) | .user' edr-process.jsonl | head -n1 | sed 's/.*\\//')
exhost=$(awk -F, '$3 ~ /mega/ {print $2}' proxy.csv | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}')
gb=$(awk -F, '$3 ~ /mega/ {s += $4} END {printf "%d", s / 1e9}' proxy.csv)
last=$(awk -F, '$3 ~ /mega/ {print $1}' proxy.csv | sort | tail -n1)
kill1=$(grep -m1 "vm process kill" esx01-shell.log | cut -d' ' -f1)
mins=$(( ($(date -u -d "$kill1" +%s) - $(date -u -d "$last" +%s)) / 60 ))
vms=$(grep -c "flat.vmdk ->" esx01-shell.log)
ext=$(grep -m1 "flat.vmdk ->" esx01-shell.log | sed 's/.*\.vmdk\.//')
note=$(grep "File created" esx01-shell.log | sed 's#.*/##')
victim=$(bash "$S/mfa-fatigue.sh" < idp-signins.jsonl | cut -d, -f1 | head -n1)

{
  echo "LANGUAGE=Rust"
  echo "FIXED_EXTENSION=no"
  echo "EXFIL_TOOL=Rclone"
  echo "C2_SOFTWARE=Cobalt Strike"
  echo "ENTRY_TICKET=$ticket"
  echo "ENTRY_USER=$user"
  echo "ATTACKER_IP=$ip"
  echo "ROGUE_TOOL_HOST=$rogue"
  echo "ADMIN_ACCOUNT=$admin"
  echo "EXFIL_HOST=$exhost"
  echo "EXFIL_GB=$gb"
  echo "MINUTES_EXFIL_TO_IMPACT=$mins"
  echo "VMS_ENCRYPTED=$vms"
  echo "RANSOM_EXT=$ext"
  echo "RANSOM_NOTE=$note"
  echo "FATIGUE_VICTIM=$victim"
} > answers.txt
cp "$S/mfa-fatigue.sh" mfa-fatigue.sh
chmod 755 mfa-fatigue.sh
