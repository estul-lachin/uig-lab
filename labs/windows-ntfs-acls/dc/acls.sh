# Sets the NTFS-style ACLs of the Labs share, once per container, before Samba starts.
# (They can't be set at build time: xattr_tdb keys them by inode, which changes in a new container.)
set -eu
MARK=/var/lib/samba/.labs-acls-set
[ -e "$MARK" ] && exit 0

sid() { samba-tool group show "$1" --attributes=objectSid | sed -n 's/^objectSid: //p'; }
KF=$(samba-tool user show kfischer --attributes=objectSid | sed -n 's/^objectSid: //p')
HR=$(sid HR-Staff); IT=$(sid IT-Staff); ALL=$(sid All-Staff)
acl() { samba-tool ntacl set "$1" "$2" --service=Labs; }

# Access masks: FA = Full Control, 0x1301bf = Modify, 0x1200a9 = Read & Execute.
# OICI = inherited by files (object inherit) and subfolders (container inherit), ID = inherited entry,
# D:P = protected (inheritance disabled), D:AI = inheritance enabled.
acl "O:DAG:DAD:(A;OICI;FA;;;SY)(A;OICI;FA;;;DA)(A;;0x1200a9;;;AU)" /srv/labs
acl "O:DAG:DAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;DA)(A;OICI;0x1301bf;;;$HR)" /srv/labs/HR-Files
acl "O:DAG:DAD:AI(A;ID;FA;;;SY)(A;ID;FA;;;DA)(A;ID;0x1301bf;;;$HR)" /srv/labs/HR-Files/payroll-2026.csv
acl "O:DAG:DAD:AI(A;OICI;0x1200a9;;;$ALL)(A;OICIID;FA;;;SY)(A;OICIID;FA;;;DA)" /srv/labs/Public
acl "O:DAG:DAD:AI(A;ID;0x1200a9;;;$ALL)(A;ID;FA;;;SY)(A;ID;FA;;;DA)" /srv/labs/Public/handbook.txt
# The mistake for the lab: Domain Users (everybody) can change the logon script.
acl "O:DAG:DAD:AI(A;OICI;0x1301bf;;;$IT)(A;OICI;0x1301bf;;;DU)(A;OICIID;FA;;;SY)(A;OICIID;FA;;;DA)" /srv/labs/IT-Tools
acl "O:DAG:DAD:AI(A;ID;0x1301bf;;;$IT)(A;ID;0x1301bf;;;DU)(A;ID;FA;;;SY)(A;ID;FA;;;DA)" /srv/labs/IT-Tools/map-drives.cmd
# Created by kfischer: the creator becomes the owner.
acl "O:${KF}G:DUD:AI(A;ID;0x1301bf;;;$IT)(A;ID;0x1301bf;;;DU)(A;ID;FA;;;SY)(A;ID;FA;;;DA)" /srv/labs/IT-Tools/update-helper.cmd
# smbd enforces the NT ACLs above; the Unix mode bits underneath must not get in their way.
chmod -R a+rwX /srv/labs
touch "$MARK"
