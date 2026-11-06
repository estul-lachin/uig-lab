# DC01: a real Active Directory domain controller (Samba 4 AD DC) with a Labs file share, provisioned at build time.
# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends samba samba-ad-dc samba-ad-provision winbind \
      ldb-tools ldap-utils dnsutils smbclient netcat-openbsd less \
 && rm -rf /var/lib/apt/lists/*
COPY dc/provision.sh /usr/local/sbin/lab-provision
RUN bash /usr/local/sbin/lab-provision && rm /usr/local/sbin/lab-provision
COPY dc/acls.sh /usr/local/sbin/lab-acls
COPY dc/start.sh /usr/local/sbin/lab-start
RUN echo 'echo "Lab windows-ntfs-acls: you are on DC01 (ridgeline.local), the share is //dc01/Labs. Answers go in /root/answers.txt. Check from the host with: ./lab check windows-ntfs-acls"' >> /root/.bashrc
WORKDIR /root
# The share's ACLs, then the DC itself: LDAP, Kerberos, DNS and the SMB file server in one process tree.
CMD ["bash", "/usr/local/sbin/lab-start"]
