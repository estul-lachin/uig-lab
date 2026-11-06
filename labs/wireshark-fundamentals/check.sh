# Checks for wireshark-fundamentals (see templates/lab/check.sh for the rules).
# Every check reads a value the learner wrote in /root/answers.txt, so all checks are
# default-false: on a fresh environment the values are empty and nothing passes.

A=/root/answers.txt

# Value for KEY: text after the first '=', with surrounding whitespace trimmed; first match only.
val() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$A" 2>/dev/null | head -n1 | sed 's/[[:space:]]*$//'; }
# Case-insensitive membership, ignoring any spaces inside the answer.
_in() { local k=$1 v; v=$(val "$k" | tr 'A-Z' 'a-z' | tr -d '[:space:]'); [ -n "$v" ] || return 1; shift; for x in "$@"; do [ "$v" = "$x" ] && return 0; done; return 1; }
# Exact, case-sensitive match (for passwords typed exactly as they crossed the wire).
_eq() { local v; v=$(val "$1"); [ -n "$v" ] && [ "$v" = "$2" ]; }
# Display-filter match: drop spaces and quotes, lowercase, then compare.
_norm() { val "$1" | tr 'A-Z' 'a-z' | sed -e 's/[[:space:]]//g' -e "s/[\"']//g"; }
_filter() { [ -n "$(_norm "$1")" ] && [ "$(_norm "$1")" = "$2" ]; }

section "1. The three panes and the cleartext login"
check "BYTES_PANE names the pane that shows the data as hex and ASCII" \
  '_in BYTES_PANE bytes bytespane packetbytes packetbytespane' "Hex on the left, ASCII on the right"
check "PROTOCOL is the cleartext remote-login protocol 10.10.10.50 uses" \
  '_in PROTOCOL telnet' "Port 23; everything in the clear"
check "SERVER_IP is the server the client logs in to" \
  '_eq SERVER_IP 10.10.10.10' "The destination of the login traffic"

section "2. Follow the TELNET stream"
check "TELNET_USER is the account that logs in" \
  '_in TELNET_USER labops' "Right-click a TELNET packet -> Follow -> TCP Stream (tshark: -z follow,tcp,ascii,<n>)"
check "TELNET_PASS is that account's password, exactly as typed" \
  '_eq TELNET_PASS "Spring2025!"' "Case-sensitive, including the trailing symbol"

section "3. Follow the FTP stream"
check "FTP_PASS is the PASS value sent for the anonymous login" \
  '_eq FTP_PASS labops@workstation.lab' "USER anonymous, then PASS ... (an email-style string)"

section "4. Display filters and custom columns"
check 'FILTER_PASSWORD matches every frame that contains the word password' \
  '_filter FILTER_PASSWORD framecontainspassword' 'frame contains "..."'
check "HTTP_HOST_FIELD is the field a custom column uses for the HTTP host" \
  '_in HTTP_HOST_FIELD http.host' "protocol.field form"
check "HTTP_HOST is the host the plain-HTTP recon targeted" \
  '_in HTTP_HOST intranet.lab.local' "The Host: header value on the GET requests"
