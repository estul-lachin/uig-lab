# Reference solution for attack-tactic-triage. Runs as root inside the container.
# Classifies each case by its ATT&CK tactic (current v19 matrix).
set -euo pipefail

cat > /root/answers.txt <<'EOF'
CASE_01=Reconnaissance
CASE_02=Resource Development
CASE_03=Initial Access
CASE_04=Execution
CASE_05=Persistence
CASE_06=Privilege Escalation
CASE_07=Stealth
CASE_08=Defense Impairment
CASE_09=Credential Access
CASE_10=Discovery
CASE_11=Lateral Movement
CASE_12=Collection
CASE_13=Command and Control
CASE_14=Exfiltration
CASE_15=Impact
V19_SPLIT=Stealth and Defense Impairment
EOF
