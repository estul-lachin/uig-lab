# The jump host I work on. Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-client \
 && rm -rf /var/lib/apt/lists/*

# Random throwaway passwords: only the hash format matters in this lab.
# Task 1: accounts to read about.
RUN useradd -m -u 1742 -s /bin/dash -c "Nadia, reporting" nadia \
 && echo "nadia:$(head -c 12 /dev/urandom | base64)" | chpasswd -c SHA512 \
 && useradd -m -s /bin/bash marco \
 && echo "marco:$(head -c 12 /dev/urandom | base64)" | chpasswd \
 && usermod -L marco

# Task 2: accounts to change.
RUN groupadd staff-ops \
 && useradd -m -s /bin/sh -G staff-ops lena \
 && useradd -m -s /bin/bash tomas \
 && echo "tomas:$(head -c 12 /dev/urandom | base64)" | chpasswd \
 && useradd -m -s /bin/bash intern

# Task 4: what the previous admin left behind.
RUN useradd -o -u 0 -g 0 -M -d /root -s /bin/bash -c "System update" sysupdate \
 && useradd -m -s /bin/bash legacy \
 && echo "legacy:$(head -c 12 /dev/urandom | base64)" | chpasswd -c MD5 \
 && useradd -M -d /var/tmp/.svc -s /bin/bash svc-cache \
 && mkdir -p /home/lena/.ssh \
 && ssh-keygen -q -t ed25519 -N "" -C "lena@laptop" -f /tmp/k1 \
 && ssh-keygen -q -t ed25519 -N "" -C "deploy@build-07" -f /tmp/k2 \
 && cat /tmp/k1.pub /tmp/k2.pub > /home/lena/.ssh/authorized_keys \
 && rm -f /tmp/k1 /tmp/k1.pub /tmp/k2 /tmp/k2.pub \
 && chown -R lena:lena /home/lena/.ssh \
 && chmod 777 /home/lena/.ssh \
 && chmod 666 /home/lena/.ssh/authorized_keys

RUN echo 'echo "Lab linux-authentication: tasks are in labs/linux-authentication/README.md. Check from the host with: ./lab check linux-authentication"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
