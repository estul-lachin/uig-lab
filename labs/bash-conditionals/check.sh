# Checks for bash-conditionals (see templates/lab/check.sh for the rules).
# The checks run your scripts with prepared arguments.

D=/root/scripts
T=/tmp/cond-test
_out() { "$@" 2>/dev/null; }
_rc() { "$@" >/dev/null 2>&1; echo $?; }

section "1. File tests (pathtype.sh)"
P=$D/pathtype.sh
_prep() { rm -rf $T; mkdir -p "$T/a dir"; echo x > "$T/a file"; ln -s "$T/a file" $T/link; ln -s $T/nowhere $T/broken; }
check "A regular file is 'file'" '[ -x $P ] && _prep && [ "$(_out $P "$T/a file")" = file ]' "[[ -f \"\$1\" ]]; quote \$1, the name has a space"
check "A directory is 'directory'" '[ -x $P ] && _prep && [ "$(_out $P "$T/a dir")" = directory ]' "[[ -d \"\$1\" ]]"
check "A symlink is 'symlink', even a broken one" '[ -x $P ] && _prep && [ "$(_out $P $T/link)" = symlink ] && [ "$(_out $P $T/broken)" = symlink ]' \
  "-f and -d follow links, and -e is false for a broken one: test -L first"
check "A missing path is 'missing' with exit status 1" '[ -x $P ] && _prep && [ "$(_out $P $T/none)" = missing ] && [ "$(_rc $P $T/none)" = 1 ]' \
  "exit 1 in the else branch"

section "2. Numeric comparison (sign.sh)"
S=$D/sign.sh
check "It prints positive, zero and negative" '[ -x $S ] && [ "$(_out $S 42)" = positive ] && [ "$(_out $S 0)" = zero ] && [ "$(_out $S -7)" = negative ]' \
  "if (( n > 0 )); then ... elif (( n == 0 )); then ... else ... fi"
check "It compares numbers, not text" '[ -x $S ] && [ "$(_out $S 10)" = positive ] && [ "$(_out $S -10)" = negative ]' \
  "Use -gt/-lt or (( )); inside [[ ]], > compares strings"
check "A non-number gives exit status 2 and a message on stderr" '[ -x $S ] && [ "$(_rc $S abc)" = 2 ] && [ "$(_rc $S 1.5)" = 2 ] && [ "$(_rc $S)" = 2 ] && [ -z "$(_out $S abc)" ] && [ -n "$($S abc 2>&1)" ]' \
  "[[ \$1 =~ ^-?[0-9]+\$ ]] || { echo \"not an integer\" >&2; exit 2; }"

section "3. Case dispatch (svc.sh)"
V=$D/svc.sh
check "start, stop and restart print starting, stopping, restarting" '[ -x $V ] && [ "$(_out $V start)" = starting ] && [ "$(_out $V stop)" = stopping ] && [ "$(_out $V restart)" = restarting ]' \
  "case \"\$1\" in start) ... ;; esac"
check "Upper-case actions work too" '[ -x $V ] && [ "$(_out $V START)" = starting ] && [ "$(_out $V Stop)" = stopping ]' \
  "Lower-case first with \${1,,}, or list patterns like start|START"
check "-h and --help print usage on stdout and exit 0" '[ -x $V ] && _out $V -h | grep -qi usage && [ "$(_rc $V --help)" = 0 ]' "-h|--help) usage; exit 0 ;;"
check "Anything else prints usage on stderr and exits 64" '[ -x $V ] && [ "$(_rc $V reload)" = 64 ] && [ "$(_rc $V)" = 64 ] && [ -z "$(_out $V reload)" ] && $V reload 2>&1 | grep -qi usage' \
  "*) usage >&2; exit 64 ;; (64 is EX_USAGE from sysexits.h)"

section "4. Regex test (is-ipv4.sh)"
I=$D/is-ipv4.sh
check "is-ipv4.sh uses [[ =~ ]]" '[ -x $I ] && grep -q "=~" $I' "[[ \$1 =~ ^...\$ ]]"
check "Valid addresses exit 0" '[ -x $I ] && for a in 10.0.0.1 192.168.1.254 0.0.0.0 255.255.255.255 8.8.8.8; do $I $a >/dev/null 2>&1 || exit 1; done' \
  "Four groups of 1-3 digits separated by dots, anchored with ^ and \$"
check "Malformed addresses exit 1" '[ -x $I ] && for a in 1.2.3 1.2.3.4.5 a.b.c.d 1.2.3.4x " 1.2.3.4" "" 1..2.3; do [ "$(_rc $I "$a")" = 1 ] || exit 1; done' \
  "Anchor both ends; an unanchored regex also matches inside longer text"
check "Octets above 255 exit 1" '[ -x $I ] && for a in 256.1.1.1 10.0.0.999 300.300.300.300; do [ "$(_rc $I $a)" = 1 ] || exit 1; done' \
  "After the match, check each part in BASH_REMATCH with (( part <= 255 ))"

section "5. Classify an address (ipclass.sh)"
C=$D/ipclass.sh
check "Private ranges are 'private'" '[ -x $C ] && for a in 10.4.5.6 172.16.0.1 172.31.255.254 192.168.0.10; do [ "$(_out $C $a)" = private ] || exit 1; done' \
  "10.0.0.0/8, 172.16.0.0/12 (172.16-172.31), 192.168.0.0/16"
check "Loopback is 'loopback'" '[ -x $C ] && [ "$(_out $C 127.0.0.1)" = loopback ] && [ "$(_out $C 127.8.8.8)" = loopback ]' "All of 127.0.0.0/8"
check "Everything else valid is 'public'" '[ -x $C ] && for a in 8.8.8.8 172.15.0.1 172.32.0.1 11.0.0.1 192.169.1.1; do [ "$(_out $C $a)" = public ] || exit 1; done' \
  "Careful at the edges: 172.15 and 172.32 are public"
check "An invalid address is 'invalid' with exit status 1" '[ -x $C ] && [ "$(_out $C 999.1.1.1)" = invalid ] && [ "$(_rc $C nope)" = 1 ]' \
  "Reuse is-ipv4.sh first"
rm -rf $T
