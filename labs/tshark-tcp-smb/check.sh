# Checks for tshark-tcp-smb (see templates/lab/check.sh for the rules).
# Every check reads a value the learner wrote in /root/answers.txt, so all checks are
# default-false: on a fresh environment the values are empty and nothing passes.

A=/root/answers.txt

# Value for KEY: text after the first '=', surrounding whitespace trimmed; first match only.
val() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$A" 2>/dev/null | head -n1 | sed 's/[[:space:]]*$//'; }
# Normalized: lowercase, spaces removed.
nz() { val "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]'; }
# Normalized membership.
inz() { local v; v=$(nz "$1"); [ -n "$v" ] || return 1; shift; for x in "$@"; do [ "$v" = "$x" ] && return 0; done; return 1; }
# Normalized, leading dashes stripped, membership (for CLI flags: "-r" or "r").
indz() { local v; v=$(nz "$1" | sed 's/^-\{1,\}//'); [ -n "$v" ] || return 1; shift; for x in "$@"; do [ "$v" = "$x" ] && return 0; done; return 1; }
# Normalized substring test.
hasz() { local v; v=$(nz "$1"); [ -n "$v" ] || return 1; case "$v" in *"$2"*) return 0;; esac; return 1; }
# Exact, case-sensitive.
eqv() { [ -n "$(val "$1")" ] && [ "$(val "$1")" = "$2" ]; }
# Share name: take the text after the last backslash (so a full UNC path also works).
shz() { nz "$1" | sed 's#.*\\##'; }
# Path with backslashes turned into forward slashes.
pz() { val "$1" | tr 'A-Z' 'a-z' | tr '\\' '/' | tr -d '[:space:]'; }

section "1. Driving tshark on a saved capture"
check "READ_FLAG reads packets from a saved capture file" \
  'indz READ_FLAG r' "tshark -_ file.pcapng"
check "FILTER_FLAG applies a Wireshark-syntax display filter" \
  'indz FILTER_FLAG y' "e.g. tshark -r file -_ 'smb2'"
check "FIELDS_MODE is the -T output mode that prints chosen fields (with -e)" \
  'indz FIELDS_MODE fields tfields' "-T ______"

section "2. Diagnosing the slow transfer"
check "LOSS_FIELD surfaces the duplicate-ACK storm" \
  'hasz LOSS_FIELD duplicate_ack' "a tcp.analysis.* field/filter"
check "CONDITION is the one-word network problem behind it" \
  'inz CONDITION packetloss loss' "the network is dropping segments"

section "3. Identifying the SMB2 transfer"
check "PROTOCOL is the application-layer protocol carrying the file read" \
  'inz PROTOCOL smb2 smb' "atop TCP/445"
check "SERVER_IP is the file server hosting the file" \
  'eqv SERVER_IP 172.16.20.8' "the destination of the SMB2 session"
check "SHARE is the share the client mounts (read smb2.tree)" \
  '[ "$(shz SHARE)" = profiles ]' "the tree it connects to, not the folder opened inside it"
check "FOLDER_PATH is the path opened inside the share (read smb2.filename)" \
  '[ "$(pz FOLDER_PATH)" = dmccoy/backup ]' "two folders deep in the share, without the file name"

section "4. Carving the file"
check "EXPORT_FLAG exports transferred objects out of the capture" \
  'hasz EXPORT_FLAG export-objects' "tshark --____-_______ smb,DIR"
