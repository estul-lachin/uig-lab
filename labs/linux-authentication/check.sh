# Checks for linux-authentication (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_shadow() { getent shadow "$1" | cut -d: -f"$2"; }

section "1. Reading passwd and shadow"
A=/root/answers.txt
check "/root/answers.txt exists" '[ -f $A ]' "Write the four KEY=value lines"
check "NADIA_UID is right" 'v=$(_kv $A NADIA_UID); [ -n "$v" ] && [ "$v" = "$(id -u nadia)" ]' "Third field of nadia's line in /etc/passwd"
check "NADIA_SHELL is right" 'v=$(_kv $A NADIA_SHELL); [ -n "$v" ] && [ "$v" = "$(getent passwd nadia | cut -d: -f7)" ]' "Last field of the line"
check "NADIA_HASH is right" 'v=$(_kv $A NADIA_HASH | tr "A-Z" "a-z" | tr -d -- "-\$"); [ "$v" = sha512 ] || [ "$v" = 6 ]' \
  "Look at the characters between the first two \$ signs of her hash in /etc/shadow"
check "LOCKED_USER is right" '[ "$(_kv $A LOCKED_USER)" = marco ]' "A locked password field starts with ! followed by a hash"

section "2. Changing accounts"
check "lena's comment is 'Lena Fischer'" '[ "$(getent passwd lena | cut -d: -f5)" = "Lena Fischer" ]' "usermod -c"
check "lena's shell is /bin/bash" '[ "$(getent passwd lena | cut -d: -f7)" = /bin/bash ]' "usermod -s"
check "lena is in group backup" 'id -nG lena | tr " " "\n" | grep -qx backup' "usermod -aG"
check "lena is still in group staff-ops" 'id lena && id -nG lena | tr " " "\n" | grep -qx staff-ops' \
  "usermod -G without -a replaces the supplementary groups; add staff-ops back"
check "tomas is locked" '_shadow tomas 2 | grep -q "^!"' "usermod -L"
check "tomas keeps his hash (locked, not wiped)" '_shadow tomas 2 | grep -q "^!\\$"' \
  "Lock with usermod -L, don't overwrite the password field"
check "intern expires on 2026-12-31" '[ "$(_shadow intern 8)" = "$(( $(date -u -d 2026-12-31 +%s) / 86400 ))" ]' \
  "usermod -e YYYY-MM-DD; chage -l intern shows it"

section "3. SSH key login to server"
K=/root/.ssh/id_rsa
check "Private key $K exists, mode 600" '[ -f $K ] && [ "$(stat -c %a $K)" = 600 ]' "ssh-keygen with the default path"
check "It is RSA, 4096 bits" 'ssh-keygen -lf $K.pub | grep -Eq "^4096 .*\(RSA\)$"' "ssh-keygen -t rsa -b 4096"
check "Its comment is backup-key" 'ssh-keygen -lf $K.pub | grep -q " backup-key (RSA)$"' "ssh-keygen -C"
check "It is protected by the passphrase" '[ -f $K ] && ! ssh-keygen -y -P "" -f $K && ssh-keygen -y -P BackupKey2026 -f $K' \
  "Passphrase BackupKey2026; ssh-keygen -p changes it on an existing key"
_keylogin() {
  local ap; ap=$(mktemp)
  printf '#!/bin/sh\necho BackupKey2026\n' > "$ap"; chmod 700 "$ap"
  SSH_ASKPASS=$ap SSH_ASKPASS_REQUIRE=force timeout 15 ssh -i $K -o IdentitiesOnly=yes \
    -o PreferredAuthentications=publickey -o PasswordAuthentication=no \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
    ops@server true
  local rc=$?; rm -f "$ap"; return $rc
}
check "Key login as ops@server works (password auth disabled for the test)" '[ -f $K ] && _keylogin' \
  "ssh-copy-id ops@server (password ops-pass), then ssh ops@server should only ask for the passphrase"

section "4. Hunting backdoors"
F=/root/findings.txt
check "/root/findings.txt exists" '[ -f $F ]' "Write the four KEY=value lines"
check "UID0_ACCOUNT is right" '[ "$(_kv $F UID0_ACCOUNT)" = sysupdate ]' "awk -F: '\$3 == 0' /etc/passwd"
check "MD5_ACCOUNT is right" '[ "$(_kv $F MD5_ACCOUNT)" = legacy ]' "Which hash in /etc/shadow starts with \$1\$?"
check "ODD_HOME_ACCOUNT is right" '[ "$(_kv $F ODD_HOME_ACCOUNT)" = svc-cache ]' "A login shell with a home outside /home"
check "ROGUE_KEY_COMMENT is right" '[ "$(_kv $F ROGUE_KEY_COMMENT)" = deploy@build-07 ]' "The last field of each key line is its comment"
check "root is the only UID 0 account" 'getent passwd root && [ "$(awk -F: "\$3 == 0" /etc/passwd | cut -d: -f1)" = root ]' \
  "userdel refuses while UID 0 runs processes; userdel -f"
check "legacy is locked" 'id legacy && _shadow legacy 2 | grep -q "^!"' "usermod -L"
check "svc-cache can no longer log in" 'id svc-cache && [ "$(getent passwd svc-cache | cut -d: -f7)" = /usr/sbin/nologin ]' "usermod -s /usr/sbin/nologin"
AK=/home/lena/.ssh/authorized_keys
check "The rogue key is gone, lena's own key stays" '[ -f $AK ] && grep -q " lena@laptop$" $AK && ! grep -q deploy@build-07 $AK' \
  "Delete only the deploy@build-07 line"
check "lena's .ssh is mode 700" '[ "$(stat -c %a /home/lena/.ssh)" = 700 ]' "chmod 700"
check "authorized_keys is mode 600, owned by lena" '[ "$(stat -c %a:%U $AK)" = 600:lena ]' "chmod 600"
