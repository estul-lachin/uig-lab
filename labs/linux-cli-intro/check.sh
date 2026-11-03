# Checks for linux-cli-intro (see templates/lab/check.sh for the rules).

A=/root/answers.txt
_kv() { sed -n "s/^$1=//p" $A 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_is() { [ "$(_kv "$1")" = "$2" ]; }
E=/root/evidence

section "1. Reading a prompt"
check "PROMPT_USER" '_is PROMPT_USER mara' "The part before @"
check "PROMPT_HOST" '_is PROMPT_HOST db-07' "Between @ and :"
check "PROMPT_DIR" '_is PROMPT_DIR /var/log' "Between : and the final symbol"
check "PROMPT_ROOT" '[ "$(_kv PROMPT_ROOT | tr A-Z a-z)" = yes ]' "# means root, \$ a regular user"

section "2. The directory tree"
check "HOME_USERS" '_is HOME_USERS "$(find /home -mindepth 1 -maxdepth 1 -type d | wc -l)"' "ls -l /home"
check "HIDDEN_FILE" '_is HIDDEN_FILE .todo-before-leave' "ls -la /home/cleo (dotfiles are hidden from plain ls)"
check "CD_RESULT" '_is CD_RESULT /var' "cd /var/log/web, then cd ../.. and pwd"

section "3. Reading files"
L=/var/log/web/access.log
check "FIRST_IP" '_is FIRST_IP "$(head -n1 $L | cut -d" " -f1)"' "head -n 1"
check "LAST_IP" '_is LAST_IP "$(tail -n1 $L | cut -d" " -f1)"' "tail -n 1"
check "ACCESS_LINES" '_is ACCESS_LINES "$(wc -l < $L)"' "cat ... | wc -l"

section "4. Pipes and grep"
check "FAILED_PASSWORD" '_is FAILED_PASSWORD 3' "grep \"Failed password\" /var/log/auth.log | wc -l"
check "FAILED_ANY_CASE" '_is FAILED_ANY_CASE 5' "grep -i failed ... | wc -l"

section "5. Help and which"
check "LS_SORT_TIME" '_is LS_SORT_TIME -t' "ls --help | grep -i time"
check "WHICH_PS" '_is WHICH_PS /usr/local/bin/ps' "Run which ps before you fix it"
check "The fake ps is gone" '[ -x /usr/bin/ps ] && [ ! -e /usr/local/bin/ps ]' "rm /usr/local/bin/ps"
check "ps now resolves to /usr/bin/ps" '[ "$(PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin command -v ps)" = /usr/bin/ps ]' \
  "hash -r clears bash's remembered path"

section "6. Evidence trail"
check "$E/notes.txt has the two lines" '[ -f $E/notes.txt ] && [ "$(cat $E/notes.txt)" = "$(printf "first finding\nfake ps in /usr/local/bin")" ]' \
  "echo ... > notes.txt, then echo ... >> notes.txt"
check "$E/err.txt holds the error from ls /nope" '[ -f $E/err.txt ] && grep -q "No such file" $E/err.txt && ! grep -qv "^ls" $E/err.txt' \
  "ls /nope 2> err.txt"

section "7. History as evidence"
check "ATTACKER_URL" '_is ATTACKER_URL http://203.0.113.50/k.sh' "cat /home/ben/.bash_history"
