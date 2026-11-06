# This path is the DC; the compose file builds WS01 from ws/Dockerfile.
# DC01: a real Active Directory domain controller (Samba 4 AD DC) with its GPOs, provisioned at build time.
# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends samba samba-ad-dc samba-ad-provision winbind \
      ldb-tools ldap-utils dnsutils smbclient netcat-openbsd less \
 && rm -rf /var/lib/apt/lists/*
COPY dc/provision.sh /usr/local/sbin/lab-provision
RUN bash /usr/local/sbin/lab-provision && rm /usr/local/sbin/lab-provision
COPY dc/start.sh /usr/local/sbin/lab-start
RUN echo 'echo "Lab ad-group-policy: this is DC01 (ridgeline.local). Work from WS01: ./lab shell ad-group-policy. Check from the host with: ./lab check ad-group-policy"' >> /root/.bashrc
WORKDIR /root
# Fix sysvol ACLs, then the DC itself: LDAP, Kerberos, DNS and the SMB server (sysvol).
CMD ["bash", "/usr/local/sbin/lab-start"]
