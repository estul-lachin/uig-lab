# Checks for linux-file-permissions (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
P=/srv/print/price-list.txt
O=/srv/print/order-form.txt
A=/root/answers.txt

section "1. Create and inspect"
check "$P exists" '[ -f $P ]' "touch"
check "INITIAL_PERMS in $A is right" 'v=$(_kv $A INITIAL_PERMS); [ "$v" = "-rw-r--r--" ] || [ "$v" = 644 ]' \
  "What ls -l showed right after touch (umask 022), e.g. -rw-r--r-- or 644"

section "2. Octal mode"
check "price-list.txt is mode 740" '[ "$(stat -c %a $P)" = 740 ]' "Owner rwx = 7, group r = 4, others nothing = 0"

section "3. Symbolic mode"
check "order-form.txt is mode 665" '[ "$(stat -c %a $O)" = 665 ]' \
  "From 751: chmod u-x,g=rw,o+r (symbolic only touches the bits you name)"

section "4. Ownership"
check "price-list.txt is owned by pia:printers" '[ "$(stat -c %U:%G $P)" = pia:printers ]' "chown pia:printers"
check "printers members can read it" '[ -f $P ] && as_user otto "cat $P"' "otto is in printers; group needs r"
check "Others cannot read it" '[ -f $P ] && id guest && ! id -nG guest | grep -qw printers && ! as_user guest "cat $P"' \
  "guest is neither the owner nor in printers"
check "Everything under archive/ is pia:printers" '[ -d /srv/print/archive ] && [ -z "$(find /srv/print/archive \( ! -user pia -o ! -group printers \) -print -quit)" ]' \
  "chown -R pia:printers /srv/print/archive"

section "5. Special bits"
check "PASSWD_SPECIAL is suid" '[ "$(_kv $A PASSWD_SPECIAL | tr A-Z a-z)" = suid ]' "ls -l /usr/bin/passwd: where is the s?"
check "TMP_SPECIAL is sticky" '[ "$(_kv $A TMP_SPECIAL | tr A-Z a-z)" = sticky ]' "Look at a normal Linux /tmp: drwxrwxrwt"
check "SGID_FILE is a file with the SGID bit" 'v=$(_kv $A SGID_FILE); [ -n "$v" ] && [ -f "$v" ] && [ -g "$v" ]' \
  "find /usr/bin -perm /2000 -type f"

section "6. Permission audit"
F=/root/findings.txt
check "SUID_BACKDOOR is right" '[ "$(_kv $F SUID_BACKDOOR)" = /var/tmp/.helper ]' "find / -xdev -perm /4000 -type f 2>/dev/null, then ask which doesn't belong"
check "WORLD_WRITABLE is right" '[ "$(_kv $F WORLD_WRITABLE)" = /etc/cron.d/cleanup ]' "find /etc /root -perm /002 -type f"
check "BAD_OWNER is right" '[ "$(_kv $F BAD_OWNER)" = /usr/local/bin/print-backup ]' "ls -l /usr/local/bin"
check "NO_STICKY is right" '[ "$(_kv $F NO_STICKY)" = /tmp ]' "ls -ld on the world-writable directories"
check "No SUID file left in /var/tmp" '[ -d /var/tmp ] && [ -z "$(find /var/tmp -perm /4000 -type f -print -quit)" ]' \
  "Delete the copy, or at least chmod u-s it"
check "The real passwd is still SUID" '[ -u /usr/bin/passwd ]' "Don't touch the legitimate SUID binaries"
check "cron.d/cleanup is no longer world-writable" '[ -f /etc/cron.d/cleanup ] && [ "$(stat -c %a /etc/cron.d/cleanup)" = 644 ]' "chmod 644"
check "print-backup is owned by root:root" '[ "$(stat -c %U:%G /usr/local/bin/print-backup)" = root:root ]' "chown root:root"
check "/tmp is 1777 again" '[ "$(stat -c %a /tmp)" = 1777 ]' "chmod 1777 /tmp (or chmod +t)"
