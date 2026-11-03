# Reference solution for users-sudo.
set -euo pipefail

# 6 (survey first, before anything changes)
full=""
for u in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'); do
  sudo -l -U "$u" 2>/dev/null | grep -Eq '\((ALL|root)( ?: ?ALL)?\) (NOPASSWD: )?ALL$' && full="$full,$u"
done

# 1-2. Account with a real password, then locked
useradd --create-home --shell /bin/bash deployer
echo "deployer:$(head -c 12 /dev/urandom | base64)" | chpasswd
passwd --lock deployer >/dev/null

# 3. Exactly one command
printf '%s\n' 'deployer ALL=(root) NOPASSWD: /usr/local/bin/reload-web' > /tmp/deployer.sudo
visudo -cf /tmp/deployer.sudo >/dev/null
install -m 0440 -o root -g root /tmp/deployer.sudo /etc/sudoers.d/deployer
rm -f /tmp/deployer.sudo

# 4. Password aging
chage --maxdays 90 --warndays 14 deployer

# 5. Audit one account
sudo -l -U deployer > /root/deployer_sudo.txt 2>&1

# 6. Close the extra routes
rm -f /etc/sudoers.d/90-migration
gpasswd -d svc-backup sudo >/dev/null
printf '%s\n' 'webdev ALL=(root) NOPASSWD: /usr/bin/tail -n 200 /var/log/web/access.log' > /tmp/webdev.sudo
visudo -cf /tmp/webdev.sudo >/dev/null
install -m 0440 -o root -g root /tmp/webdev.sudo /etc/sudoers.d/50-webdev-logs
rm -f /tmp/webdev.sudo
visudo -c >/dev/null

{
  echo "FULL_ROOT=${full#,}"
  echo "SHELL_ESCAPE=webdev"
} > /root/answers.txt
