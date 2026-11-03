# Reference solution for conti-case-study.
set -eu   # no pipefail: several pipes end in head -n1, which closes them early
umask 022
S=$(pwd)          # ./lab solve runs us from the temp dir that holds find-beacons.sh
cd /root/case
E=events.jsonl
ts() { jq -r --argjson r "$1" 'select(.RecordID == $r) | .UtcTime | strptime("%Y-%m-%d %H:%M:%S") | mktime' $E; }

# The Office document whose process started a child process.
lure_rec=$(jq -r 'select(.EventID == 1 and (.Image | test("WINWORD")) ) | .RecordID' $E | while read -r r; do
  img=$(jq -r --argjson r "$r" 'select(.RecordID == $r) | .Image' $E)
  host=$(jq -r --argjson r "$r" 'select(.RecordID == $r) | .Computer' $E)
  if jq -e --arg h "$host" --arg p "$img" 'select(.EventID == 1 and .Computer == $h and .ParentImage == $p)' $E >/dev/null; then echo "$r"; fi
done | head -n1)
lure=$(jq -r --argjson r "$lure_rec" 'select(.RecordID == $r) | .CommandLine' $E | sed 's/.*\\//; s/"$//')
p0=$(jq -r --argjson r "$lure_rec" 'select(.RecordID == $r) | .Computer' $E)
exec_rec=$(jq -r --arg h "$p0" 'select(.EventID == 1 and .Computer == $h and (.ParentImage | test("WINWORD"))) | .RecordID' $E | head -n1)
loader=$(jq -r --argjson r "$exec_rec" 'select(.RecordID == $r) | .Image' $E)
c2=$(jq -r --arg h "$p0" --arg i "$loader" 'select(.EventID == 3 and .Computer == $h and .Image == $i) | .DestinationIp' $E | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}')
c2_rec=$(jq -r --arg ip "$c2" 'select(.EventID == 3 and .DestinationIp == $ip) | .RecordID' $E | head -n1)
beacon=$(jq -rs --arg ip "$c2" '[.[] | select(.EventID == 3 and .DestinationIp == $ip) | .UtcTime | strptime("%Y-%m-%d %H:%M:%S") | mktime] | sort
  | [range(1; length) as $i | .[$i] - .[$i - 1]] | sort | .[length / 2 | floor]' $E)
cred_rec=$(jq -r 'select(.EventID == 10 and (.TargetImage | test("lsass"))) | .RecordID' $E | head -n1)
esc_rec=$(jq -r 'select(.EventID == 4742 and .SubjectUserName == "ANONYMOUS LOGON") | .RecordID' $E | head -n1)
lat_rec=$(jq -r 'select(.EventID == 4624 and .TargetUserName == "Administrator") | .RecordID' $E | head -n1)
exf_rec=$(jq -r 'select(.EventID == 1 and (.Image | test("rclone"))) | .RecordID' $E | head -n1)
data=$(jq -r --argjson r "$exf_rec" 'select(.RecordID == $r) | .CommandLine' $E | awk '{print $3}')
enc=$(jq -r 'select(.EventID == 11 and (.TargetFilename | endswith(".CONTI"))) | .Computer' $E | sort -u)
enc_img=$(jq -r 'select(.EventID == 11 and (.TargetFilename | endswith(".CONTI"))) | .Image' $E | head -n1)
imp_rec=$(jq -r --arg i "$enc_img" 'select(.EventID == 1 and .Image == $i) | .RecordID' $E | head -n1)
spared=$(comm -23 <(jq -r '.Computer' $E | grep -- '-WS' | sort -u) <(printf '%s\n' "$enc"))
hours=$(( ($(ts "$imp_rec") - $(ts "$lure_rec")) / 3600 ))

{
  echo "GROUP=Wizard Spider"
  echo "EXTENSION=.CONTI"
  echo "RANSOM_NOTE=readme.txt"
  echo "LEAK_SITE=Conti News"
  echo "LURE=$lure"
  echo "PATIENT_ZERO=$p0"
  echo "C2_IP=$c2"
  echo "BEACON_SECONDS=$beacon"
  echo "ESCALATION=Zerologon"
  echo "EXFIL_DATA=$data"
  echo "ENCRYPTED_HOSTS=$(printf '%s\n' "$enc" | grep -c .)"
  echo "SPARED_HOST=$spared"
  echo "HOURS_TO_IMPACT=$hours"
} > answers.txt

printf '%s\n' stage,record "delivery,$lure_rec" "execution,$exec_rec" "command-and-control,$c2_rec" \
  "credential-access,$cred_rec" "privilege-escalation,$esc_rec" "lateral-movement,$lat_rec" \
  "exfiltration,$exf_rec" "impact,$imp_rec" > opportunities.csv

cp "$S/find-beacons.sh" /root/case/find-beacons.sh
chmod 755 /root/case/find-beacons.sh
