# The workstation I investigate from. Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends bind9-dnsutils sudo \
 && rm -rf /var/lib/apt/lists/*

# A regular user with sudo, to practise writing root-owned files the right way.
RUN useradd -m -s /bin/bash analyst \
 && echo 'analyst ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analyst \
 && chmod 440 /etc/sudoers.d/analyst

RUN echo 'echo "Lab dns-resolution: tasks are in labs/dns-resolution/README.md. Check from the host with: ./lab check dns-resolution"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
