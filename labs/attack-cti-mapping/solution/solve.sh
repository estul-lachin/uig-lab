# Reference solution for attack-cti-mapping. Runs as root inside the container.
set -euo pipefail

cat > /root/answers.txt <<'EOF'
MAP_1=T1566.001
MAP_2=T1059.001
MAP_3=T1053.005
MAP_4=T1003.001
MAP_5=T1087.002
MAP_6=T1021.002
MAP_7=T1071.001
MAP_8=T1041
MAP_9=T1070.001
MAP_10=T1486
ATOMIC=Atomic Red Team
EMULATION=CALDERA
DEFENSE=D3FEND
PURPLE=purple teaming
STIX=STIX/TAXII
EOF
