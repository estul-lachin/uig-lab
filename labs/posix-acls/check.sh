# Checks for posix-acls (see templates/lab/check.sh for the rules).

R=/srv/casework
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
A=/root/answers.txt

section "1. Target directory"
check "$R is a directory owned by root:root" '[ -d $R ] && [ "$(stat -c %U:%G $R)" = root:root ]' "mkdir; it should stay root:root"
check "Its mode is 750" '[ "$(stat -c %a $R 2>/dev/null)" = 750 ]' "chmod 750. With an ACL, the group digit shows the mask"
check "auditor is not in root's group" 'id auditor && ! id -nG auditor | grep -qw root' "Give access with an ACL, not a group"

section "2. Access ACL for auditor"
check "getfacl shows user:auditor:r-x on $R" 'getfacl -cp $R 2>/dev/null | grep -qx "user:auditor:r-x"' "setfacl -m u:auditor:rx $R"
check "auditor can list the directory" '[ -d $R ] && as_user auditor "ls $R"' "r lists, x enters"
check "auditor cannot create files in it" '[ -d $R ] && as_user auditor "ls $R" && ! as_user auditor "touch $R/.probe-auditor"' "No w for auditor"
check "Other users still get nothing" '[ -d $R ] && id finn && ! as_user finn "ls $R"' "others stays ---"

section "3. Default ACL"
check "A default ACL gives auditor r--" 'getfacl -cp $R 2>/dev/null | grep -qx "default:user:auditor:r--"' "setfacl -d -m u:auditor:r $R"
check "auditor can read a file created afterwards" '[ -d $R ] && rm -f $R/.probe && echo probe > $R/.probe && as_user auditor "cat $R/.probe"' \
  "New files inherit the default ACL"
check "...but cannot change it" '[ -f $R/.probe ] && as_user auditor "cat $R/.probe" && ! as_user auditor "echo x >> $R/.probe"' "r only"
rm -f $R/.probe

section "4. Verify with getfacl"
check "/root/acl.txt holds the current getfacl output" '[ -s /root/acl.txt ] && [ "$(grep -v "^#" /root/acl.txt | grep .)" = "$(getfacl -p $R 2>/dev/null | grep -v "^#" | grep .)" ]' \
  "getfacl $R > /root/acl.txt, after the other tasks"

section "5. Reading effective rights"
check "FINN_EFFECTIVE is right" '[ "$(_kv $A FINN_EFFECTIVE)" = r-- ]' "getfacl /srv/hr/budget.csv: the #effective comment, or the entry ANDed with mask"
check "FINN_CAN_WRITE is right" '[ "$(_kv $A FINN_CAN_WRITE | tr A-Z a-z)" = no ]' "Try it: su finn -c \"echo x >> /srv/hr/budget.csv\""

section "6. A quiet exposure"
check "EXPOSED_FILE is right" '[ "$(_kv $A EXPOSED_FILE)" = /srv/hr/salaries.csv ]' "getfacl -R -s -p /srv/hr lists only files with extended ACLs"
check "EXPOSED_TO is right" '[ "$(_kv $A EXPOSED_TO)" = intern ]' "The named user entry"
check "intern can no longer read salaries.csv" '[ -f /srv/hr/salaries.csv ] && id intern && ! as_user intern "cat /srv/hr/salaries.csv"' "setfacl -x u:intern ..."
check "intern has no ACL entries left under /srv/hr" '[ -d /srv/hr ] && ! getfacl -R -p /srv/hr 2>/dev/null | grep -q "user:intern:"' "Also the one on /srv/hr itself"
check "The legitimate ACLs are kept" 'getfacl -cp /srv/hr/policies | grep -qx "group:finance-ro:r-x" && getfacl -cp /srv/hr/budget.csv | grep -q "^user:finn:"' \
  "Remove single entries with -x, not everything with -b"
check "hana (hrteam) can still read salaries.csv" 'as_user hana "cat /srv/hr/salaries.csv"' "Don't change the owner, group or mode"
