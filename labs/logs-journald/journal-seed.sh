#!/bin/bash
# Builds the lab's journal at image build time: writes entries in journal export format and converts them
# with systemd-journal-remote into a real journal file that journalctl reads. Removed after the build.
set -euo pipefail
mid=$(cat /etc/machine-id)
out=/var/log/journal/$mid
mkdir -p "$out"
BOOT1=1a2b3c4d5e6f40718293a4b5c6d7e8f9   # 2026-10-29, a quiet day
BOOT2=9f8e7d6c5b4a43219876fedcba012345   # 2026-10-30, the incident
mono=0
# e BOOT "YYYY-MM-DD HH:MM:SS" UNIT IDENT PID UID PRIORITY MESSAGE   (UNIT "-" = kernel message)
e() {
  local ts; ts=$(date -u -d "$2" +%s)
  mono=$(( mono + 1000000 ))
  printf '__REALTIME_TIMESTAMP=%s\n__MONOTONIC_TIMESTAMP=%s\n_BOOT_ID=%s\n_MACHINE_ID=%s\n_HOSTNAME=web-01\n' \
    "$(( ts * 1000000 ))" "$mono" "$1" "$mid"
  if [ "$3" = - ]; then
    printf '_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\n'
  else
    printf '_TRANSPORT=syslog\n_SYSTEMD_UNIT=%s\nSYSLOG_IDENTIFIER=%s\n_PID=%s\n_UID=%s\n' "$3" "$4" "$5" "$6"
  fi
  printf 'PRIORITY=%s\nMESSAGE=%s\n\n' "$7" "$8"
}
{
  e $BOOT1 "2026-10-29 08:00:01" - - - - 6 "Linux version 6.8.0-45-generic (buildd@lcy02) #45-Ubuntu SMP"
  e $BOOT1 "2026-10-29 08:00:05" ssh.service sshd 610 0 6 "Server listening on 0.0.0.0 port 22."
  e $BOOT1 "2026-10-29 09:12:44" ssh.service sshd 702 0 6 "Accepted publickey for maya from 10.0.4.10 port 51022 ssh2"
  e $BOOT1 "2026-10-29 12:00:01" cron.service CRON 801 0 6 "(root) CMD (/usr/local/bin/backup.sh)"
  e $BOOT1 "2026-10-29 23:59:50" - - - - 6 "reboot: Restarting system"

  e $BOOT2 "2026-10-30 00:00:30" - - - - 6 "Linux version 6.8.0-45-generic (buildd@lcy02) #45-Ubuntu SMP"
  e $BOOT2 "2026-10-30 00:00:31" - - - - 4 "ACPI: _OSC evaluation for CPUs failed, trying _PDC"
  e $BOOT2 "2026-10-30 00:00:35" ssh.service sshd 611 0 6 "Server listening on 0.0.0.0 port 22."
  e $BOOT2 "2026-10-30 00:00:36" nginx.service nginx 640 0 6 "nginx started"
  e $BOOT2 "2026-10-30 01:30:12" nginx.service nginx 640 0 3 "open() \"/var/www/html/wp-login.php\" failed (2: No such file or directory)"
  for s in 01 04 07 10 13 16 19 22 25 28 31 34; do
    e $BOOT2 "2026-10-30 02:14:$s" ssh.service sshd 900 0 5 "Failed password for root from 203.0.113.50 port 4$s$s ssh2"
  done
  e $BOOT2 "2026-10-30 02:14:36" ssh.service sshd 901 0 5 "Failed password for deploy from 203.0.113.50 port 41036 ssh2"
  e $BOOT2 "2026-10-30 02:14:37" ssh.service sshd 901 0 6 "Accepted password for deploy from 203.0.113.50 port 41037 ssh2"
  e $BOOT2 "2026-10-30 02:15:10" ssh.service sudo 955 1001 5 "deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/bash"
  e $BOOT2 "2026-10-30 02:16:02" cron.service CRON 960 0 6 "(root) CMD (/usr/local/bin/backup.sh)"
  e $BOOT2 "2026-10-30 02:17:45" nginx.service nginx 640 3 3 "connect() to unix:/run/php/php-fpm.sock failed (11: Resource temporarily unavailable)"
  e $BOOT2 "2026-10-30 02:21:13" - - - - 3 "Out of memory: Killed process 4242 (kworkerds) total-vm:2621440kB, anon-rss:1968312kB"
  e $BOOT2 "2026-10-30 02:21:14" nginx.service nginx 640 0 3 "worker process 650 exited on signal 9"
  e $BOOT2 "2026-10-30 07:45:00" ssh.service sshd 1201 0 6 "Accepted publickey for maya from 10.0.4.10 port 52210 ssh2"
} > /tmp/seed.export
/usr/lib/systemd/systemd-journal-remote --output="$out/system.journal" /tmp/seed.export
rm -f /tmp/seed.export
