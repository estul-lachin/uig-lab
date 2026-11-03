# Checks for unix-permissions (see templates/lab/check.sh for the rules).

K=/home/kai
_mode() { stat -c %a "$1" 2>/dev/null; }
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]" | tr A-Z a-z; }
A=/root/answers.txt

section "1. Secret file"
check "$K/secret.txt is mode 600, owned by kai" '[ "$(stat -c %a:%U $K/secret.txt 2>/dev/null)" = 600:kai ]' "chown kai; chmod 600"
check "lee cannot read it" '[ -f $K/secret.txt ] && ! as_user lee "cat $K/secret.txt"' "Group and others get nothing"
check "kai can read and write it" '[ -f $K/secret.txt ] && as_user kai "echo x >> $K/secret.txt && cat $K/secret.txt"' "Owner rw"

section "2. Team directory"
T=$K/team
check "$T is mode 750, kai:crew" '[ "$(stat -c %a:%U:%G $T 2>/dev/null)" = 750:kai:crew ]' "chown kai:crew; chmod 750"
check "lee (crew) can list it but not create files" '[ -d $T ] && as_user lee "ls $T" && ! as_user lee "touch $T/.probe"' "Group r-x, no w"
check "zoe cannot even list it" '[ -d $T ] && id zoe && ! as_user zoe "ls $T"' "Others ---"

section "3. Script, symbolically"
H=$K/bin/hello.sh
check "hello.sh exists with a shebang and prints hi" '[ -f $H ] && head -n1 $H | grep -q "^#!" && [ "$(bash $H)" = hi ]' "#!/bin/bash, then echo hi"
check "Its mode is 754 (owner and group gained x, nothing else changed)" '[ "$(_mode $H)" = 754 ]' \
  "From 644, chmod u+x,g+x gives 754; a plain +x would also give others x"
check "It is group crew, and lee can run it" '[ -f $H ] && [ "$(stat -c %G $H)" = crew ] && [ "$(as_user lee "$H")" = hi ]' "chgrp crew; lee also needs x on $K/bin"
check "zoe cannot run it" '[ -f $H ] && id zoe && ! as_user zoe "$H"' "Others r-- means read, not run"

section "4. The project tree"
P=$K/project
check "Nothing under project has any 'other' bits" '[ -d $P ] && [ -z "$(find $P -perm /o=rwx -print -quit)" ]' "chmod -R o= $P (or o-rwx)"
check "Owner and group bits of the files are unchanged" '[ "$(_mode $P/plan.md)" = 640 ] && [ "$(_mode $P/budget.csv)" = 640 ] && [ "$(_mode $P/drafts/d1.md)" = 640 ]' \
  "They were 646: only the last digit should change"
check "The crew can now enter drafts/" '[ "$(_mode $P/drafts)" = 750 ] && as_user lee "cat $P/drafts/d1.md"' \
  "g+rX: r for all, and capital X adds x only to directories (and files that already have some x)"
check "No file became executable" '[ -d $P ] && [ -z "$(find $P -type f -perm /111 -print -quit)" ]' "Lower-case x on -R would hit the files too"

section "5. umask"
check "kai's login shell uses umask 027" '[ "$(as_user kai "bash -lc umask" 2>/dev/null | tail -n1)" = 0027 ]' "Put umask 027 in /home/kai/.profile"
check "New files kai creates are 640, new directories 750" 'as_user kai "bash -lc \"rm -rf /tmp/um.f /tmp/um.d; touch /tmp/um.f; mkdir /tmp/um.d\"" && [ "$(_mode /tmp/um.f)" = 640 ] && [ "$(_mode /tmp/um.d)" = 750 ]' \
  "Files start from 666, directories from 777, minus the umask"
rm -rf /tmp/um.f /tmp/um.d

section "6. What a directory's bits mean"
check "LISTONLY_LS: can zoe list /srv/listonly?" '[ "$(_kv $A LISTONLY_LS)" = yes ]' "Try su zoe -c \"ls /srv/listonly\" (the names may come with errors)"
check "LISTONLY_CAT: can zoe read report.txt in it?" '[ "$(_kv $A LISTONLY_CAT)" = no ]' "Opening a file inside needs x on the directory"
check "DROPBOX_LS: can zoe list /srv/dropbox?" '[ "$(_kv $A DROPBOX_LS)" = no ]' "No r on the directory"
check "DROPBOX_CREATE: can zoe create a file in it?" '[ "$(_kv $A DROPBOX_CREATE)" = yes ]' "w+x on a directory allows creating entries"
check "DROPBOX_DELETE: can zoe delete existing.txt (owned by root, mode 644)?" '[ "$(_kv $A DROPBOX_DELETE)" = yes ]' \
  "Deleting is a change to the directory, not the file; only the sticky bit prevents it"
check "existing.txt is still there" '[ -f /srv/dropbox/existing.txt ]' "If you tested the delete, recreate it as root"
