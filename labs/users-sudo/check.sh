# Checks for users-sudo (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_status() { passwd -S "$1" 2>/dev/null | awk '{print $2}'; }
_full_root() { sudo -l -U "$1" 2>/dev/null | grep -Eq '\((ALL|root)( ?: ?ALL)?\) (NOPASSWD: )?ALL$'; }
A=/root/answers.txt
R=/etc/sudoers.d/deployer

section "1. The account"
check "deployer exists with a home and bash" 'id deployer && [ -d /home/deployer ] && [ "$(getent passwd deployer | cut -d: -f7)" = /bin/bash ]' "useradd -m -s /bin/bash deployer"
check "It has a real password hash underneath" 'getent shadow deployer | cut -d: -f2 | grep -Eq "^!?\\$"' \
  "Set one with chpasswd or passwd; without one the account starts out locked and locking means nothing"

section "2. Locked"
check "passwd -S reports L" '[ "$(_status deployer)" = L ]' "passwd -l deployer"
check "The hash is kept behind the !" 'getent shadow deployer | cut -d: -f2 | grep -q "^!\\$"' "Lock, don't wipe the password"

section "3. One command through sudo"
check "$R is mode 440, root-owned" '[ "$(stat -c %a:%U $R 2>/dev/null)" = 440:root ]' "chmod 440"
check "Every sudoers file passes visudo -c" 'visudo -c >/dev/null 2>&1' "visudo -c shows the file and line of a syntax error"
check "deployer can run reload-web without a password, even while locked" '[ -f $R ] && [ "$(_status deployer)" = L ] && as_user deployer "sudo -n /usr/local/bin/reload-web" | grep -q "reloaded by deployer"' \
  "deployer ALL=(root) NOPASSWD: /usr/local/bin/reload-web. A locked password doesn't stop NOPASSWD rules (or SSH keys)"
check "...and nothing else" '[ -f $R ] && as_user deployer "sudo -n /usr/local/bin/reload-web" >/dev/null && ! as_user deployer "sudo -n id" && ! as_user deployer "sudo -n /bin/bash -c true"' \
  "Name the command with its full path; no ALL"

section "4. Password aging"
check "Maximum password age is 90 days" '[ "$(getent shadow deployer | cut -d: -f5)" = 90 ]' "chage -M 90 deployer"
check "Warning period is 14 days" '[ "$(getent shadow deployer | cut -d: -f6)" = 14 ]' "chage -W 14 deployer"

section "5. Audit one account"
# Compare the rules part only: sudo wraps the Defaults lines to the terminal width.
_rules() { sed -n "/may run the following/,\$p" | tr -s " \t" " "; }
check "/root/deployer_sudo.txt is the sudo -l -U output" '[ -f /root/deployer_sudo.txt ] && grep -q reload-web /root/deployer_sudo.txt && [ "$(_rules < /root/deployer_sudo.txt)" = "$(sudo -l -U deployer 2>&1 | _rules)" ]' \
  "sudo -l -U deployer > /root/deployer_sudo.txt (after task 3)"

section "6. Every route to root"
check "FULL_ROOT lists who could get full root before your changes" '[ "$(_kv $A FULL_ROOT | tr , "\n" | sort | paste -sd, -)" = admin,intern,svc-backup ]' \
  "sudo -l -U for each account, or read /etc/sudoers, /etc/sudoers.d/* and the sudo group; comma-separated"
check "SHELL_ESCAPE names the account whose single allowed program can start a root shell" '[ "$(_kv $A SHELL_ESCAPE)" = webdev ]' \
  "Which allowed program can run other commands from inside it? (GTFOBins)"
check "intern no longer has any sudo rights" 'id intern && ! sudo -l -U intern 2>/dev/null | grep -q "may run"' "Remove the drop-in that grants it; visudo -c afterwards"
check "svc-backup is out of the sudo group" 'id svc-backup && ! id -nG svc-backup | tr " " "\n" | grep -qx sudo' "gpasswd -d svc-backup sudo"
check "admin keeps full sudo (with a password)" '_full_root admin && ! sudo -l -U admin | grep -q "NOPASSWD: ALL"' "Leave the legitimate admin alone"
check "webdev may only tail one fixed log file" '[ -f /etc/sudoers.d/50-webdev-logs ] && sudo -l -U webdev | grep -q "/usr/bin/tail -n 200 /var/log/web/access.log$" && ! sudo -l -U webdev | grep -Eq "less|\\*"' \
  "/usr/bin/tail -n 200 /var/log/web/access.log, with no wildcard: * in sudoers arguments also matches ../../etc/shadow"
check "...and that works" 'as_user webdev "sudo -n /usr/bin/tail -n 200 /var/log/web/access.log" | grep -q GET && ! as_user webdev "sudo -n /usr/bin/tail -n 200 /etc/shadow"' "Test it as webdev"
