# Checks for linux-server-setup (see templates/lab/check.sh for the rules).

section "1. SSH key"
check "/root/.ssh has a private key" 'ls /root/.ssh/id_* 2>/dev/null | grep -qv "\.pub$"' \
  "Generate a keypair with ssh-keygen and accept the default path"
check "The matching public key exists" 'for k in /root/.ssh/id_*; do case $k in *.pub) continue;; esac; [ -f "$k.pub" ] || exit 1; done; ls /root/.ssh/id_*.pub' \
  "ssh-keygen writes the public key next to the private one, with .pub appended"
check "The private key is readable by its owner only" 'for k in /root/.ssh/id_*; do case $k in *.pub) continue;; esac; m=$(stat -c %a "$k"); [ "$m" = 600 ] || [ "$m" = 400 ] || exit 1; done; ls /root/.ssh/id_* >/dev/null' \
  "ssh refuses private keys that others can read: chmod 600"

section "2. User nora"
check "Group auditors exists" 'getent group auditors' "groupadd"
check "User nora exists" 'id nora' "useradd"
check "Primary group is auditors" '[ "$(id -gn nora)" = auditors ]' "useradd -g sets the primary group"
check "Home is /home/nora and it exists" '[ "$(getent passwd nora | cut -d: -f6)" = /home/nora ] && [ -d /home/nora ]' \
  "useradd -d sets the path, -m actually creates the directory"
check "nora owns her home" '[ "$(stat -c %U /home/nora)" = nora ]' "useradd -m creates it with the right owner"
check "Login shell is /bin/bash" '[ "$(getent passwd nora | cut -d: -f7)" = /bin/bash ]' "useradd -s"

section "3. Directory /var/payroll"
check "User hugo and group accounting exist" 'id hugo && getent group accounting' "useradd, groupadd"
check "hugo is a member of accounting" 'id -nG hugo | tr " " "\n" | grep -qx accounting' "usermod -aG (the -a matters)"
check "/var/payroll is a directory" '[ -d /var/payroll ]' "mkdir"
check "Owner hugo, group accounting" '[ "$(stat -c %U:%G /var/payroll)" = hugo:accounting ]' "chown user:group"
check "Mode is 770" '[ "$(stat -c %a /var/payroll)" = 770 ]' "chmod 770"
check "Group members can write" '[ -d /var/payroll ] && as_user hugo "touch /var/payroll/.probe && rm /var/payroll/.probe"' \
  "hugo should be able to create files there through the group"
check "Other users cannot list it" '[ -d /var/payroll ] && id nora && ! id -nG nora | grep -qw accounting && ! as_user nora "ls /var/payroll"' \
  "Others must get no access at all (needs user nora from task 2)"

section "4. Install script"
check "/root/banner-tools.sh exists and is executable" '[ -x /root/banner-tools.sh ]' "chmod +x"
check "It starts with a shebang" 'head -n1 /root/banner-tools.sh | grep -q "^#!"' "First line: #!/bin/bash"
check "It refreshes the package lists" 'grep -Eq "apt(-get)? +update" /root/banner-tools.sh' "apt-get update"
check "It installs without prompting" 'grep -Eq "apt(-get)? .*install" /root/banner-tools.sh && grep -Eq "install.*(-y|--yes|--assume-yes)|(-y|--yes|--assume-yes).*install" /root/banner-tools.sh' \
  "apt-get install -y ..."
check "It cleans the apt cache" 'grep -Eq "apt(-get)? +(clean|autoclean)" /root/banner-tools.sh' "apt-get clean"
check "figlet is installed" 'command -v figlet' "Run the script"
check "lolcat is installed" 'dpkg -s lolcat 2>/dev/null | grep -q "^Status: install ok installed"' "Run the script"
check "No downloaded .deb files are left" 'command -v figlet && ! ls /var/cache/apt/archives/*.deb' "apt-get clean empties /var/cache/apt/archives"

section "5. Error log"
check "/home/student/welcome-errors.txt exists" '[ -f /home/student/welcome-errors.txt ]' \
  "Run /home/student/welcome.sh and redirect stderr into that file"
check "It contains the mkdir error" 'grep -q "mkdir" /home/student/welcome-errors.txt' "2> redirects file descriptor 2 (stderr)"
check "It contains no normal output" '[ -s /home/student/welcome-errors.txt ] && ! grep -q "Welcome aboard" /home/student/welcome-errors.txt' \
  "Only stderr goes in the file; stdout stays on the terminal"

section "6. Server inventory"
_inv() { sed -n "s/^$1=//p" /root/server-info.txt | head -n1 | tr -d "[:space:]"; }
_largest_disk() {
  local name
  name=$(lsblk -dbno SIZE,NAME | sort -n | tail -n1 | awk '{print $2}')
  lsblk -dno NAME,SIZE | awk -v n="$name" '$1 == n {print $2}'
}
check "/root/server-info.txt exists" '[ -f /root/server-info.txt ]' "Create it with the four KEY=value lines"
check "LARGEST_DISK matches lsblk" 'v=$(_inv LARGEST_DISK); [ -n "$v" ] && [ "$v" = "$(_largest_disk)" ]' \
  "The biggest SIZE among the disks (TYPE disk), exactly as lsblk prints it, e.g. 926.3G"
check "MOUNTPOINT is a real mount point" 'm=$(_inv MOUNTPOINT); [ -n "$m" ] && lsblk -nlo MOUNTPOINTS | grep -qxF "$m"' \
  "Copy one path from the MOUNTPOINTS column of lsblk"
check "MEM_TOTAL matches free -h" 'v=$(_inv MEM_TOTAL); [ -n "$v" ] && [ "$v" = "$(free -h | awk "/^Mem:/{print \$2}")" ]' \
  "The total column of the Mem: row, e.g. 7.7Gi"
check "CPU_CORES matches nproc" 'v=$(_inv CPU_CORES); [ -n "$v" ] && [ "$v" = "$(nproc)" ]' "nproc"
