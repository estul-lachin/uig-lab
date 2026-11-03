# Reference solution for linux-server-setup.
set -euo pipefail

# 1. SSH key (no passphrase so it runs unattended)
mkdir -p /root/.ssh && chmod 700 /root/.ssh
[ -f /root/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -C "lab-key" -f /root/.ssh/id_ed25519 -q

# 2. User nora
getent group auditors >/dev/null || groupadd auditors
id nora >/dev/null 2>&1 || useradd -m -d /home/nora -s /bin/bash -g auditors nora

# 3. Directory /var/payroll
getent group accounting >/dev/null || groupadd accounting
id hugo >/dev/null 2>&1 || useradd -m -s /bin/bash hugo
usermod -aG accounting hugo
mkdir -p /var/payroll
chown hugo:accounting /var/payroll
chmod 770 /var/payroll

# 4. Install script
cat > /root/banner-tools.sh <<'SCRIPT'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y figlet lolcat
apt-get clean
SCRIPT
chmod +x /root/banner-tools.sh
/root/banner-tools.sh >/dev/null

# 5. Error log (the script fails on purpose, so ignore its exit code)
/home/student/welcome.sh 2> /home/student/welcome-errors.txt || true

# 6. Server inventory
largest=$(lsblk -dbno SIZE,NAME | sort -n | tail -n1 | awk '{print $2}')
{
  echo "LARGEST_DISK=$(lsblk -dno NAME,SIZE | awk -v n="$largest" '$1==n{print $2}')"
  echo "MOUNTPOINT=$(lsblk -nlo MOUNTPOINTS | grep -m1 .)"
  echo "MEM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')"
  echo "CPU_CORES=$(nproc)"
} > /root/server-info.txt
