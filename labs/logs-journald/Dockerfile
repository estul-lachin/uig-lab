# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# journalctl (from systemd) reads the journal; logrotate rotates plain-text logs.
RUN apt-get update \
 && apt-get install -y --no-install-recommends systemd systemd-journal-remote logrotate \
 && rm -rf /var/lib/apt/lists/* \
 && systemd-machine-id-setup >/dev/null

# Tasks 1-4: a journal with two boots and one bad night. No systemd runs in the container; journalctl
# reads the files under /var/log/journal directly.
COPY journal-seed.sh /tmp/journal-seed.sh
RUN bash /tmp/journal-seed.sh >/dev/null 2>&1 && rm -f /tmp/journal-seed.sh

# Task 5: rotated plain-text auth logs, one of them compressed.
RUN printf '%s\n' 'Oct 30 02:14:01 web-01 sshd[900]: Failed password for root from 203.0.113.50 port 40101 ssh2' \
      'Oct 30 07:45:00 web-01 sshd[1201]: Accepted publickey for maya from 10.0.4.10 port 52210 ssh2' > /var/log/auth.log \
 && printf '%s\n' 'Oct 23 11:02:10 web-01 sshd[512]: Failed password for admin from 198.51.100.23 port 33000 ssh2' \
      'Oct 23 11:02:14 web-01 sshd[512]: Failed password for admin from 198.51.100.23 port 33001 ssh2' \
      'Oct 23 11:05:00 web-01 sshd[530]: Accepted publickey for maya from 10.0.4.10 port 50000 ssh2' > /var/log/auth.log.1 \
 && printf '%s\n' 'Oct 16 03:00:01 web-01 sshd[301]: Failed password for root from 192.0.2.77 port 22000 ssh2' \
      'Oct 16 03:00:04 web-01 sshd[301]: Failed password for root from 192.0.2.77 port 22001 ssh2' \
      'Oct 16 03:00:07 web-01 sshd[301]: Failed password for oracle from 192.0.2.77 port 22002 ssh2' > /var/log/auth.log.2 \
 && gzip /var/log/auth.log.2

# Tasks 6-7: the application whose log needs rotating.
RUN mkdir -p /var/log/orders && seq -f "order %g accepted" 1 500 > /var/log/orders/orders.log

RUN echo 'echo "Lab logs-journald: tasks are in labs/logs-journald/README.md. Check from the host with: ./lab check logs-journald"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
