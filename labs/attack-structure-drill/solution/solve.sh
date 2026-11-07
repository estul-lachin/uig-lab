# Reference solution for attack-structure-drill. Runs as root inside the container.
set -euo pipefail

cat > /root/answers.txt <<'EOF'
ID_A=tactic
ID_B=technique
ID_C=sub-technique
ID_D=software
ID_E=group
ID_F=campaign
ID_G=mitigation
PAIN_MOST=TTPs
PAIN_LEAST=Hash Values
LEVEL_1=tactic
LEVEL_2=technique
LEVEL_3=procedure
ACRONYM=Adversarial Tactics, Techniques, and Common Knowledge
MAINTAINER=MITRE
PHILOSOPHY=threat-informed defense
EOF
