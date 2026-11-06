# Reference solution for syn-flood-analysis.
# Derives the capture-specific answers with tshark, then writes /root/answers.txt.
set -euo pipefail
umask 022

CAP=/opt/captures/flood/synflood.pcapng

# Victim: the destination that dominates the storm.
victim=$(tshark -r "$CAP" -T fields -e ip.dst 2>/dev/null | sort | uniq -c | sort -rn | head -n1 | awk '{print $2}')

# Targeted port: the destination port the SYN probes land on.
port=$(tshark -r "$CAP" -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' -T fields -e tcp.dstport 2>/dev/null \
         | sort | uniq -c | sort -rn | head -n1 | awk '{print $2}')

{
  printf '%s\n' '# SYN flood analysis - answers'
  printf 'ATTACK_TYPE=%s\n'  'flood'
  printf 'ATTACK_FLAG=%s\n'  'SYN'
  printf 'SYN_FILTER=%s\n'   'tcp.flags.syn==1 && tcp.flags.ack==0'
  printf 'VICTIM_IP=%s\n'    "$victim"
  printf 'TARGET_PORT=%s\n'  "$port"
  printf 'VICTIM_REPLY=%s\n' 'SYN-ACK'
  printf 'SPOOFING=%s\n'     'source IP spoofing'
  printf 'L2_TAG=%s\n'       'VLAN'
} > /root/answers.txt
