# Reference solution for windows-ntfs-acls: answers read from the share's ACLs, then the fix.
set -eu
umask 022
P='Lab-AD-2026!'
for _ in $(seq 1 30); do timeout 10 smbclient -L //dc01 -U "Administrator%$P" >/dev/null 2>&1 && break; sleep 2; done
acl() { smbcacls //dc01/Labs "$1" -U "Administrator%$P"; }
perm() { acl "$1" | grep -F "\\$2:" | head -n1 | awk -F/ '{print $NF}'; }
level() { case "$1" in FULL) echo "Full Control" ;; RWXD) echo Modify ;; READ) echo "Read & Execute" ;; *) echo "$1" ;; esac; }

ctl_hr=$(acl HR-Files | sed -n 's/^CONTROL://p')
case "|$ctl_hr|" in *"|PD|"*) inh=disabled ;; *) inh=enabled ;; esac
via=$(for g in $(samba-tool group listmembers All-Staff); do samba-tool group listmembers "$g" | grep -qx kfischer && echo "$g"; done; true)
planted=$(for f in $(ls /srv/labs/IT-Tools); do acl "IT-Tools/$f" | grep -q '^OWNER:RIDGELINE\\Domain Admins' || echo "$f"; done; true)
{
  echo "HR_PERMISSION=$(level "$(perm HR-Files HR-Staff)")"
  echo "ADMIN_PERMISSION=$(level "$(perm HR-Files 'Domain Admins')")"
  echo "INHERITANCE=$inh"
  echo "PUBLIC_PERMISSION=$(level "$(perm Public All-Staff)")"
  echo "FULL_CODE=F"
  echo "PROTECTED_FLAG=PD"
  echo "MODIFY_LETTERS=$(perm HR-Files HR-Staff)"
  echo "READ_VIA=$via"
  echo "AUTH_PROCESS=lsass.exe"
  echo "AD_SERVICE=NTDS"
  echo "DC_REMOVED_DB=SAM"
  echo "REG_HIVE=HKLM"
  echo "WRITABLE_FOLDER=IT-Tools"
  echo "WRITABLE_GROUP=Domain Users"
  echo "PLANTED_FILE=$planted"
  echo "PLANTED_BY=$(acl "IT-Tools/$planted" | sed -n 's/^OWNER:RIDGELINE\\//p')"
} > /root/answers.txt

smbcacls //dc01/Labs IT-Tools -U "Administrator%$P" --propagate-inheritance \
  -M 'ACL:RIDGELINE\Domain Users:ALLOWED/OI|CI/READ' >/dev/null
