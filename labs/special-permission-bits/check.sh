# Checks for special-permission-bits (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
A=/root/answers.txt
W=/usr/local/bin/whoami-root
_unpackaged_suid() { find /usr -xdev -perm -4000 -type f 2>/dev/null | while read -r f; do dpkg -S "$f" >/dev/null 2>&1 || echo "$f"; done; }

section "1. SUID"
check "WHOAMI_EUID shows what the SUID copy of id reported" '[ "$(_kv $A WHOAMI_EUID)" = "0(root)" ]' \
  "Run $W as guest and read the euid= part"
check "SCRIPT_SUID_WORKS is right" '[ "$(_kv $A SCRIPT_SUID_WORKS | tr A-Z a-z)" = no ]' \
  "Try a SUID shell script that prints \$(id -u) as guest; Linux ignores SUID on scripts"

section "2. SGID directory"
S=/srv/projects
check "$S is mode 2770, root:devs" '[ "$(stat -c %a:%U:%G $S 2>/dev/null)" = 2770:root:devs ]' "chgrp devs, chmod 2770"
check "A file dana creates belongs to group devs" '[ -d $S ] && rm -f $S/.p && as_user dana "umask 002; touch $S/.p" && [ "$(stat -c %G $S/.p)" = devs ]' \
  "Without SGID it would get dana's primary group"
check "omar can work on it too" '[ -f $S/.p ] && as_user omar "echo x >> $S/.p"' "The file is created with umask 002 (group-writable); the directory must let devs in and write"
check "guest cannot enter" '[ -d $S ] && id guest && ! as_user guest "ls $S"' "Others get ---"
rm -f $S/.p

section "3. Sticky directory"
U=/srv/dropbox
check "$U is mode 1777" '[ "$(stat -c %a $U 2>/dev/null)" = 1777 ]' "chmod 1777"
check "Everyone can create files" '[ -d $U ] && rm -f $U/.d $U/.g && as_user dana "touch $U/.d" && as_user guest "touch $U/.g"' "The 777 part"
check "guest cannot delete dana's file" '[ -f $U/.d ] && ! as_user guest "rm -f $U/.d" ; [ -f $U/.d ]' "The sticky bit (t): only the owner may delete"
rm -f $U/.d $U/.g

section "4. SUID audit"
check "/root/suid_list.txt lists every SUID file under /usr" '[ -f /root/suid_list.txt ] && [ "$(sort /root/suid_list.txt | grep .)" = "$(find /usr -xdev -perm -4000 -type f 2>/dev/null | sort)" ]' \
  "find /usr -xdev -perm -4000 -type f | sort > /root/suid_list.txt (do it last, after task 5)"
check "/root/suid_count.txt holds the number" '[ -f /root/suid_count.txt ] && [ "$(tr -d "[:space:]" < /root/suid_count.txt)" = "$(find /usr -xdev -perm -4000 -type f 2>/dev/null | wc -l)" ]' \
  "wc -l"

section "5. The backdoor"
check "ROGUE_SUID is right" '[ "$(_kv $A ROGUE_SUID)" = /usr/local/lib/.cache/indexer ]' \
  "dpkg -S <file> says which package installed a file; one SUID file belongs to none"
check "ROGUE_IS is right" '[ "$(_kv $A ROGUE_IS)" = find ]' "Compare it with the real programs: cmp, or its --version output"
check "No unpackaged SUID file is left under /usr" '[ -e /usr/bin/passwd ] && [ -z "$(_unpackaged_suid)" ]' \
  "Remove the backdoor and your own whoami-root (or chmod u-s them)"
check "The packaged SUID programs are untouched" '[ -u /usr/bin/passwd ] && [ -u /usr/bin/su ]' "Only remove what no package owns"
