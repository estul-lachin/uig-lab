# AVW-SRV11, the legacy file server you administer. Always a pinned tag; prefer images with arm64 builds.
FROM ubuntu:24.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends samba smbclient nmap iproute2 procps \
 && rm -rf /var/lib/apt/lists/*
COPY config/smb.conf /etc/samba/smb.conf
COPY config/start-smb.sh /usr/local/sbin/start-smb
COPY case/ /root/case/
RUN chmod 755 /usr/local/sbin/start-smb \
 && echo 'echo "Lab wannacry-case-study: you are root on AVW-SRV11 (10.253.82.10); the outbreak logs are in /root/case."' >> /root/.bashrc
ENV MIN=NT1
WORKDIR /root/case
CMD ["sh", "-c", "start-smb; exec sleep infinity"]
