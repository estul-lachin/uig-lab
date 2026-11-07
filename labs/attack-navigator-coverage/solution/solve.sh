# Reference solution for attack-navigator-coverage. Runs as root inside the container.
#
# Map the six report steps to techniques, build the Navigator layer, then compute
# the gaps against the coverage layer (chain minus coverage).
set -euo pipefail

# The attack-chain layer (a valid ATT&CK Navigator Enterprise layer).
cat > /root/attack-layer.json <<'JSON'
{
  "name": "Operation Sandpiper - attack chain",
  "versions": { "attack": "17", "navigator": "5.1.0", "layer": "4.5" },
  "domain": "enterprise-attack",
  "description": "Techniques observed in the Operation Sandpiper intrusion.",
  "techniques": [
    { "techniqueID": "T1566.001", "score": 1, "comment": "Word attachment from spoofed vendor" },
    { "techniqueID": "T1059.001", "score": 1, "comment": "PowerShell script" },
    { "techniqueID": "T1105",     "score": 1, "comment": "downloaded an extra tool" },
    { "techniqueID": "T1003.001", "score": 1, "comment": "LSASS memory dump" },
    { "techniqueID": "T1021.001", "score": 1, "comment": "RDP to the finance server" },
    { "techniqueID": "T1486",     "score": 1, "comment": "ransomware encryption" }
  ]
}
JSON

# Gap analysis: coverage-layer.json covers T1059.001, T1003.001, T1486; the three
# chain techniques NOT covered are the blind spots.
cat > /root/answers.txt <<'EOF'
GAPS=T1566.001, T1105, T1021.001
UNIT=layer
FORMAT=JSON
OVERLAY=a score expression (e.g. a + b)
ANALYSIS=gap analysis
EOF
