# Reference solution for lockbit-case-study.
set -euo pipefail
umask 022
cd /root/case
E=events.jsonl

ip=$(jq -r 'select(.EventID == 4625 and .LogonType == 10) | .IpAddress' $E | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}')
read -r acct host < <(jq -r --arg ip "$ip" 'select(.EventID == 4624 and .IpAddress == $ip) | "\(.TargetUserName) \(.Computer)"' $E | head -n1)
admin=$(jq -r 'select(.EventID == 1 and (.Image | test("psexec"; "i"))) | .User' $E | head -n1 | sed 's/.*\\//')
data=$(jq -r 'select(.EventID == 1 and (.Image | test("rclone"; "i"))) | .CommandLine' $E | awk '{print $3}' | head -n1)
ext=$(jq -r 'select(.EventID == 11 and (.TargetFilename | test("README"))) | .TargetFilename' $E | head -n1 | sed 's/.*\\//; s/\.README\.txt$//')
hosts=$(jq -r --arg x ".$ext" 'select(.EventID == 11 and (.TargetFilename | endswith($x))) | .Computer' $E | sort -u)
spared=$(comm -23 <(jq -r '.Computer' $E | grep -- '-WS' | sort -u) <(printf '%s\n' "$hosts"))

{
  echo "EXFIL_TOOL=StealBit"
  echo "SPREAD_PROTOCOL=SMB"
  echo "FIRST_EXT=.abcd"
  echo "SECOND_EXT=.lockbit"
  echo "TAKEDOWN=Operation Cronos"
  echo "ATTACKER_IP=$ip"
  echo "ENTRY_ACCOUNT=$acct"
  echo "ENTRY_HOST=$host"
  echo "ADMIN_ACCOUNT=$admin"
  echo "EXFIL_DATA=$data"
  echo "ENCRYPTED_HOSTS=$(printf '%s\n' "$hosts" | grep -c .)"
  echo "SPARED_HOST=$spared"
  echo "RANSOM_EXT=$ext"
} > answers.txt

cat > map.csv <<'CSV'
record,technique
10172,T1078
10236,T1046
10272,T1003.001
10346,T1021.002
10438,T1567.002
10629,T1484.001
10689,T1490
10690,T1070.001
10700,T1491.001
10693,T1486
CSV

cat > detect-shadow.sh <<'SH'
#!/usr/bin/env bash
# Flag shadow-copy deletion in Sysmon process-creation events (JSON Lines on stdin): print RecordIDs.
jq -r 'select(.Channel == "Sysmon" and .EventID == 1)
  | select((.Image | ascii_downcase | test("\\\\(vssadmin|wmic)\\.exe$"))
       and (.CommandLine | ascii_downcase | test("delete\\s+shadows|resize\\s+shadowstorage|shadowcopy\\s+delete")))
  | .RecordID'
SH
chmod 755 detect-shadow.sh
