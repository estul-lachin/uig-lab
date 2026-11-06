# Checks for firewall-stateful-egress (see templates/lab/check.sh for the rules).
# The learner edits /root/host.nft and APPLIES it with:  nft -f /root/host.nft
# These checks read the live, loaded ruleset, so every check is default-false: on a
# fresh environment nothing is loaded and nothing passes.

R="$(nft list ruleset 2>/dev/null)"
OUT="$(nft list chain inet fw output 2>/dev/null)"
has() { printf '%s\n' "$R" | grep -qiE "$1"; }
# True when the first match of pattern $1 comes before the first match of $2 in the output chain.
before() {
  local a b
  a=$(printf '%s\n' "$OUT" | grep -niE "$1" | head -n1 | cut -d: -f1)
  b=$(printf '%s\n' "$OUT" | grep -niE "$2" | head -n1 | cut -d: -f1)
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]
}

section "1. Default-deny and stateful rules"
check "the input chain defaults to deny (policy drop)" \
  'has "hook input priority filter; policy drop"' "the safe baseline for inbound"
check "the output chain defaults to deny (egress filtering)" \
  'has "hook output priority filter; policy drop"' "default-deny on the way out, too"
check "established/related traffic is accepted (stateful)" \
  'has "ct state established,related accept"' "so replies to allowed flows return"
check "invalid connection-state packets are dropped" \
  'has "ct state invalid drop"' "ct state invalid drop"

section "2. First-match ordering, drop vs reject"
check "egress to the C2 server (198.51.100.66) is silently dropped" \
  'has "ip daddr 198\.51\.100\.66.*drop"' "drop, not reject - don't reveal the firewall to the malware"
check "the C2 drop is evaluated BEFORE the broad web allow (first-match)" \
  'before "ip daddr 198\.51\.100\.66.*drop" "tcp dport.*443.*accept"' "order the deny above the allow, or 443 wins"
check "outbound SMB (tcp/445) is rejected (fails fast, not silent)" \
  'has "tcp dport 445 reject"' "reject contrasts with the silent C2 drop"

section "3. Egress allow-list and 5-tuple match"
check "normal egress is allowed: DNS and web" \
  'has "dport 53 accept" && has "tcp dport.*443.*accept"' "udp/tcp 53 and tcp 80,443"
check "inbound SSH is allowed only from the mgmt subnet (a 5-tuple match)" \
  'has "ip saddr 10\.50\.99\.0/24 tcp dport 22.*accept"' "saddr + protocol + dport together"
