# Checks for syn-flood-analysis (see templates/lab/check.sh for the rules).
# Every check reads a value the learner wrote in /root/answers.txt, so all checks are
# default-false: on a fresh environment the values are empty and nothing passes.

A=/root/answers.txt

# Value for KEY: text after the first '=', surrounding whitespace trimmed; first match only.
val() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$A" 2>/dev/null | head -n1 | sed 's/[[:space:]]*$//'; }
# Normalized: lowercase, spaces removed.
nz() { val "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]'; }
# Normalized membership.
inz() { local v; v=$(nz "$1"); [ -n "$v" ] || return 1; shift; for x in "$@"; do [ "$v" = "$x" ] && return 0; done; return 1; }
# Normalized substring test.
hasz() { local v; v=$(nz "$1"); [ -n "$v" ] || return 1; case "$v" in *"$2"*) return 0;; esac; return 1; }
# Exact, case-sensitive.
eqv() { [ -n "$(val "$1")" ] && [ "$(val "$1")" = "$2" ]; }
# Reply flags, collapsed to alphanumerics: "SYN-ACK", "SYN/ACK", "syn ack" -> "synack".
rz() { val "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'; }

section "1. Scan or flood?"
check "ATTACK_TYPE classifies the burst (many sources, one port, no completed sessions)" \
  'inz ATTACK_TYPE flood' "a scan fans out across ports; this fans in to one"
check "ATTACK_FLAG is the single TCP flag set on the probes" \
  'inz ATTACK_FLAG syn' "the first step of the 3-way handshake"
check "SYN_FILTER isolates only the SYN probes (SYN set, ACK clear)" \
  'hasz SYN_FILTER tcp.flags.syn==1 && hasz SYN_FILTER tcp.flags.ack==0' "two tcp.flags.* conditions joined with &&"

section "2. The victim and the spoofing"
check "VICTIM_IP is the host under attack (destination of the storm)" \
  'eqv VICTIM_IP 10.20.30.40' "the dominant ip.dst"
check "TARGET_PORT is the single port the flood is aimed at" \
  'eqv TARGET_PORT 80' "the dominant tcp.dstport (digits only)"
check "VICTIM_REPLY is what the victim returns for each SYN (half-open)" \
  '[ "$(rz VICTIM_REPLY)" = synack ]' "SYN + ACK, the second step of the handshake"
check "SPOOFING names the technique hiding the real attacker" \
  'hasz SPOOFING spoof' "thousands of forged, often sequential, source IPs"

section "3. Layer 2"
check "L2_TAG is the tagging present on every frame" \
  'inz L2_TAG vlan 8021q dot1q 802.1q' "a layer between Ethernet and IP"
