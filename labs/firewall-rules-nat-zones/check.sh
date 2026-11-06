# Checks for firewall-rules-nat-zones (see templates/lab/check.sh for the rules).
# The learner edits /root/edge.nft and APPLIES it with:  nft -f /root/edge.nft
# These checks read the live, loaded ruleset, so every check is default-false: on a
# fresh environment nothing is loaded and nothing passes.

R="$(nft list ruleset 2>/dev/null)"
has() { printf '%s\n' "$R" | grep -qiE "$1"; }

section "1. Default-deny and stateful rules"
check "the forward chain defaults to deny (policy drop)" \
  'has "hook forward priority filter; policy drop"' "set the forward chain policy to drop"
check "established/related traffic is accepted" \
  'has "ct state established,related accept"' "the stateful allow rule"

section "2. Zone rules (WAN / LAN / DMZ)"
check "LAN is allowed out to the WAN (lan0 -> wan0)" \
  'has "iifname \"lan0\" oifname \"wan0\".*accept"' "an accept rule from lan0 to wan0"
check "the DMZ is allowed out to the WAN (dmz0 -> wan0)" \
  'has "iifname \"dmz0\" oifname \"wan0\".*accept"' "DMZ servers reach the internet, not the LAN"
check "the DMZ is blocked from reaching the LAN (segmentation)" \
  'has "iifname \"dmz0\" oifname \"lan0\".*(drop|reject)"' "an explicit dmz0 -> lan0 drop or reject"

section "3. NAT"
check "internal traffic leaving the WAN is masqueraded (SNAT/PAT)" \
  'has "oifname \"wan0\" masquerade"' "a postrouting masquerade on wan0"
check "inbound WAN tcp/443 is DNATed to the DMZ web server (port-forward)" \
  'has "dnat (ip )?to 10\.50\.20\.10:443"' "a prerouting dnat to 10.50.20.10:443"
check "the forwarded HTTPS is allowed through to the DMZ server (wan0 -> dmz0 :443)" \
  'has "iifname \"wan0\" oifname \"dmz0\".*tcp dport 443.*accept"' "the filter must permit the DNATed flow"
