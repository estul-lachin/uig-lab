# Checks for windows-ntfs-acls (see templates/lab/check.sh for the rules).
# Runs on DC01; access is tested for real, over SMB, as the domain users.

A=/root/answers.txt
P='Lab-AD-2026!'
S=//dc01/Labs
_kv() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
_n() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-'; }
_any() { _v=$(_kv "$1"); shift; [ -n "$_v" ] || return 1; for _e in "$@"; do [ "$(_n "$_v")" = "$(_n "$_e")" ] && return 0; done; return 1; }
_as() { timeout 30 smbclient "$S" -U "$1%$P" -c "$2" >/dev/null 2>&1 && ! timeout 30 smbclient "$S" -U "$1%$P" -c "$2" 2>&1 | grep -q NT_STATUS_; }
# _overwrite USER FILE: can USER overwrite FILE? Its content is put back afterwards (same inode, so the ACL stays).
_overwrite() { printf 'check\n' > /tmp/.kl-put; _b=$(mktemp); cat "/srv/labs/$2" > "$_b"; _as "$1" "put /tmp/.kl-put $2"; _r=$?; cat "$_b" > "/srv/labs/$2"; rm -f "$_b"; return $_r; }
_put() { printf 'check\n' > /tmp/.kl-put; _as "$1" "put /tmp/.kl-put $2"; _r=$?; rm -f "/srv/labs/$2"; return $_r; }

for _ in $(seq 1 30); do timeout 10 smbclient -L //dc01 -U "Administrator%$P" >/dev/null 2>&1 && break; sleep 2; done

section "0. The file server"
check "DC01 serves the Labs share" 'timeout 20 smbclient -L //dc01 -U "Administrator%$P" 2>/dev/null | grep -q Labs' \
  "Samba needs a few seconds after ./lab up; run the check again"

section "1. Reading permissions (the course questions)"
check "HR_PERMISSION: what HR-Staff has on HR-Files" '_any HR_PERMISSION Modify M' "smbcacls shows it as letters; which Windows level is read, write, execute and delete?"
check "ADMIN_PERMISSION: what Domain Admins has on HR-Files" '_any ADMIN_PERMISSION "Full Control" Full F' "FULL"
check "INHERITANCE: enabled or disabled on HR-Files" '_any INHERITANCE disabled off' "The CONTROL line"
check "PUBLIC_PERMISSION: what All-Staff has on Public" '_any PUBLIC_PERMISSION "Read & Execute" "Read and Execute" "Read&Execute" RX' "READ in smbcacls"
check "FULL_CODE: the icacls letter for Full Control" '_any FULL_CODE F' "(F), (M), (RX)"

section "2. Reading them closer"
check "PROTECTED_FLAG: the CONTROL flag that means inheritance is off" '_any PROTECTED_FLAG PD' "Compare the CONTROL line of HR-Files with Public"
check "MODIFY_LETTERS: how smbcacls writes Modify" '_any MODIFY_LETTERS RWXD' "Read, write, execute, delete"
check "READ_VIA: the group through which kfischer can read Public" '_any READ_VIA Warehouse-Staff' \
  "All-Staff holds groups, not people: samba-tool group listmembers"

section "3. Windows internals"
check "AUTH_PROCESS: the process that handles logons and caches credentials" '_any AUTH_PROCESS lsass.exe lsass' "Local Security Authority Subsystem Service"
check "AD_SERVICE: the short service name of AD Domain Services" '_any AD_SERVICE NTDS' "Same name as the database file, without .dit"
check "DC_REMOVED_DB: the local account database a DC no longer has" '_any DC_REMOVED_DB SAM' "Security Account Manager"
check "REG_HIVE: the hive with machine-wide OS and service settings" '_any REG_HIVE HKLM HKEY_LOCAL_MACHINE' "HKEY_..."

section "4. The writable logon-script folder"
check "WRITABLE_FOLDER: the folder every domain user can change" '_any WRITABLE_FOLDER IT-Tools' "Look for a broad group with RWXD"
check "WRITABLE_GROUP: the group that should not have that right" '_any WRITABLE_GROUP "Domain Users" "RIDGELINE\\Domain Users"' "Everybody in the domain is in it"
check "PLANTED_FILE: the file that does not belong there" '_any PLANTED_FILE update-helper.cmd' "Compare the files and what they do"
check "PLANTED_BY: the account that created it" '_any PLANTED_BY kfischer "RIDGELINE\\kfischer"' "The creator of a file becomes its OWNER"

section "5. Fix the ACL"
check "kfischer can still read the logon script, but no longer create files in IT-Tools" '_as kfischer "get IT-Tools/map-drives.cmd /dev/null" && ! _put kfischer IT-Tools/.kl-test-kf' \
  "Domain Users needs Read & Execute there, not Modify: smbcacls -M"
check "...nor overwrite the script itself" '_as kfischer "get IT-Tools/map-drives.cmd /dev/null" && ! _overwrite kfischer IT-Tools/map-drives.cmd' \
  "Files keep the entries they inherited until you propagate: smbcacls --help"
check "IT-Staff (sbrennan) can still create files there" '_put sbrennan IT-Tools/.kl-test-it' "Change the Domain Users entry, leave IT-Staff alone"
