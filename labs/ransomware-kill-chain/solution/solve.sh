# Reference solution for ransomware-kill-chain.
set -euo pipefail
cd /root/intel
mkdir -p iocs

refang() { sed -e 's/\[\.\]/./g' -e 's/hxxp/http/g'; }
sep='(\.|\[\.\])'
grep -oE "[0-9]{1,3}$sep[0-9]{1,3}$sep[0-9]{1,3}$sep[0-9]{1,3}" report.txt | grep -F '[.]' | refang | sort -u > iocs/ips.txt
grep -oE "([a-z0-9-]+$sep)*[a-z0-9-]+\[\.\][a-z][a-z0-9-]*" report.txt | refang | sort -u > iocs/domains.txt
grep -oE '\b[0-9a-f]{64}\b' report.txt | sort -u > iocs/sha256.txt

echo "id,killchain,tactic,technique" > map.csv
cat >> map.csv <<'M'
1,Weaponization,Resource Development,T1650
2,Reconnaissance,Reconnaissance,T1595.002
3,Delivery,Initial Access,T1133
4,Exploitation,Execution,T1059.001
5,Installation,Persistence,T1053.005
6,Command and Control,Command and Control,T1071.001
7,Actions on Objectives,Credential Access,T1003.001
8,Actions on Objectives,Lateral Movement,T1021.001
9,Actions on Objectives,Discovery,T1087.002
10,Actions on Objectives,Exfiltration,T1567.002
11,Actions on Objectives,Impact,T1490
12,Actions on Objectives,Impact,T1486
M

{
  echo "EXTORTION_MODEL=triple"
  echo "AFFILIATE=tern"
  echo "BROKER_EVENT=1"
  echo "C2_DOMAIN=update-cdn.top"
} > answers.txt
