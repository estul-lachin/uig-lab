#!/bin/sh
# Start Samba with this server's minimum protocol (MIN, e.g. NT1 or SMB2_02), once per container start.
set -e
if grep -q @MIN@ /etc/samba/smb.conf; then sed -i "s/@MIN@/$MIN/" /etc/samba/smb.conf; fi
mkdir -p /srv/exports && echo "plant export $(hostname)" > /srv/exports/README.txt
id ops >/dev/null 2>&1 || useradd -M -s /usr/sbin/nologin ops
printf 'Lab-Smb-2026\nLab-Smb-2026\n' | smbpasswd -s -a ops >/dev/null
smbd -D
