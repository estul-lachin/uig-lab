# WS01: a domain member workstation that applies the GPOs with samba-gpupdate.
# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends samba winbind krb5-user samba-common-bin \
      samba-dsdb-modules python3-samba python3-cryptography smbclient ldb-tools dnsutils \
      netcat-openbsd cron less \
 && rm -rf /var/lib/apt/lists/*
COPY ws/start.sh /usr/local/sbin/lab-start
RUN echo 'echo "Lab ad-group-policy: you are on WS01, a member of ridgeline.local. The DC is dc01. Apply policy with samba-gpupdate --force, read it with samba-gpupdate --rsop. Check from the host with: ./lab check ad-group-policy"' >> /root/.bashrc
WORKDIR /root
CMD ["bash", "/usr/local/sbin/lab-start"]
