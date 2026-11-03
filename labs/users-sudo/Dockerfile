# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo less \
 && rm -rf /var/lib/apt/lists/*

# Task 3: the one thing the deploy account may do as root.
RUN printf '#!/bin/sh\necho "web reloaded by $SUDO_USER"\n' > /usr/local/bin/reload-web && chmod 755 /usr/local/bin/reload-web

# Task 6: the existing accounts and sudo rules. Passwords are random; nobody needs them.
# The image's default 'ubuntu' account (in the sudo group) is removed so the audit has one clear answer.
RUN userdel -r ubuntu 2>/dev/null || true \
 && for u in admin svc-backup intern webdev; do useradd -m -s /bin/bash "$u"; echo "$u:$(head -c 12 /dev/urandom | base64)" | chpasswd; done \
 && mkdir -p /var/log/web && echo '203.0.113.9 - - GET /' > /var/log/web/access.log \
 && usermod -aG sudo admin \
 && usermod -aG sudo svc-backup \
 && echo 'webdev ALL=(root) NOPASSWD: /usr/bin/less /var/log/*' > /etc/sudoers.d/50-webdev-logs \
 && printf '%s\n' '# temporary, remove after the migration' 'Defaults:intern !requiretty' 'intern ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-migration \
 && chmod 440 /etc/sudoers.d/50-webdev-logs /etc/sudoers.d/90-migration

RUN echo 'echo "Lab users-sudo: tasks are in labs/users-sudo/README.md. Check from the host with: ./lab check users-sudo"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
