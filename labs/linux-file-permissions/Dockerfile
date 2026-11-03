# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# People and groups of the print shop.
RUN groupadd printers \
 && useradd -m -s /bin/bash pia \
 && useradd -m -s /bin/bash -G printers otto \
 && useradd -m -s /bin/bash guest \
 && mkdir -p /srv/print/archive/2025/q4 /srv/print/archive/2026 \
 && touch /srv/print/archive/2025/q4/invoice-0412.pdf /srv/print/archive/2026/invoice-0007.pdf \
 && printf 'Name:\nCopies:\n' > /srv/print/order-form.txt \
 && chmod 751 /srv/print/order-form.txt

# What a careless (or malicious) admin left behind, for task 6.
RUN cp /bin/bash /var/tmp/.helper && chmod 4755 /var/tmp/.helper \
 && mkdir -p /etc/cron.d \
 && printf '*/30 * * * * root find /var/tmp -mtime +7 -delete\n' > /etc/cron.d/cleanup \
 && chmod 666 /etc/cron.d/cleanup \
 && printf '#!/bin/sh\ntar czf /var/backups/print.tgz /srv/print\n' > /usr/local/bin/print-backup \
 && chmod 755 /usr/local/bin/print-backup \
 && chown nobody:nogroup /usr/local/bin/print-backup \
 && chmod 0777 /tmp

RUN echo 'echo "Lab linux-file-permissions: tasks are in labs/linux-file-permissions/README.md. Check from the host with: ./lab check linux-file-permissions"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
