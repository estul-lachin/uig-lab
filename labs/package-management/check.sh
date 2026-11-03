# Checks for package-management (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q " ok installed$"; }  # "hold ok installed" once held
A=/root/answers.txt

section "1. Install"
check "jq is installed" '_installed jq' "apt update, then apt install -y jq"
check "jq works" 'echo "{\"a\":7}" | jq -r .a | grep -qx 7' "It should parse JSON"

section "2. Inspect"
check "/root/jq.pkg.txt is the dpkg -s record for jq" '[ -f /root/jq.pkg.txt ] && grep -qx "Package: jq" /root/jq.pkg.txt && grep -qx "Version: $(dpkg-query -W -f="\${Version}" jq 2>/dev/null)" /root/jq.pkg.txt' \
  "dpkg -s jq > /root/jq.pkg.txt"
check "JQ_DEPENDS lists jq's direct dependencies" 'v=$(_kv $A JQ_DEPENDS); [ -n "$v" ] && [ "$v" = "$(dpkg-query -W -f="\${Depends}" jq | tr -d " ")" ]' \
  "The Depends: line of dpkg -s, as printed (spaces don't matter)"

section "3. Files"
check "/root/jq.files.txt is the dpkg -L list for jq" '[ -f /root/jq.files.txt ] && [ "$(cat /root/jq.files.txt)" = "$(dpkg -L jq 2>/dev/null)" ]' "dpkg -L jq > /root/jq.files.txt"
check "JQ_OWNER_OF_BINARY says which package ships /usr/bin/jq" '[ "$(_kv $A JQ_OWNER_OF_BINARY)" = jq ]' "dpkg -S /usr/bin/jq"

section "4. Hold"
check "jq is on hold" 'apt-mark showhold | grep -qx jq' "apt-mark hold jq"
check "/root/holds.txt holds the apt-mark showhold output" '[ -f /root/holds.txt ] && [ "$(cat /root/holds.txt)" = "$(apt-mark showhold)" ]' "apt-mark showhold > /root/holds.txt"

section "5. Sources snapshot"
_srclines() { cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null | grep -v "^[[:space:]]*#" | grep .; }
check "/root/sources.backup contains every active line of every APT source file" '[ -s /root/sources.backup ] && [ -z "$(comm -23 <(_srclines | sort -u) <(sort -u /root/sources.backup))" ]' \
  "Ubuntu 24.04 keeps its sources in /etc/apt/sources.list.d/ubuntu.sources (deb822); sources.list only has a comment"
check "It includes the deb822 entries" 'grep -q "^URIs:" /root/sources.backup 2>/dev/null' "cat the *.sources files too"

section "6. Rogue repository"
check "ROGUE_REPO_FILE is right" '[ "$(_kv $A ROGUE_REPO_FILE)" = /etc/apt/sources.list.d/updates-mirror.list ]' \
  "Which source isn't Ubuntu's? apt-cache policy, or read the files"
check "ROGUE_REPO_RISK names the option that disables signature checks" '[ "$(_kv $A ROGUE_REPO_RISK)" = trusted=yes ]' "Look inside the [ ] of that line"
check "The rogue repository is gone, Ubuntu's sources are not" '[ -f $A ] && [ ! -e /etc/apt/sources.list.d/updates-mirror.list ] && [ -f /etc/apt/sources.list.d/ubuntu.sources ] && ! grep -rq 203.0.113.50 /etc/apt/' \
  "Delete that file only"

section "7. Tampered binary"
check "TAMPERED_FILE is right" '[ "$(_kv $A TAMPERED_FILE)" = /usr/bin/tty ]' \
  "dpkg -V lists files that differ from their package; filter out the 'missing' docs. A 5 in column 3 means the checksum changed"
check "TAMPERED_PACKAGE is right" '[ "$(_kv $A TAMPERED_PACKAGE)" = coreutils ]' "dpkg -S /usr/bin/tty"
check "/usr/bin/tty matches its package again" '[ -f $A ] && [ -z "$(dpkg -V coreutils 2>/dev/null | grep -v "^missing" | grep " /usr/bin/tty$")" ]' \
  "apt install --reinstall <package>"
check "tty is the real program" '[ -f /usr/bin/tty ] && ! head -c 2 /usr/bin/tty | grep -q "#!"' "The real tty is a compiled program, not a script"
