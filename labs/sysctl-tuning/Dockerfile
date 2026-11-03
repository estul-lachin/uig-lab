# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends procps \
 && rm -rf /var/lib/apt/lists/*

# Task 6: a drop-in someone added "for the VPN". Its name sorts after the usual 90-something files.
RUN printf '%s\n' '# vpn gateway tweaks - do not remove' 'net.ipv4.ip_forward = 1' 'net.ipv4.conf.all.accept_redirects = 1' \
      > /etc/sysctl.d/99-zz-vpn.conf

RUN echo 'echo "Lab sysctl-tuning: tasks are in labs/sysctl-tuning/README.md. Check from the host with: ./lab check sysctl-tuning"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
