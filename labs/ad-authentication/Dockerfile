# DC01: a real Active Directory domain controller (Samba 4 AD DC) with a Kerberoastable service account, provisioned at build time.
# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends samba samba-ad-dc samba-ad-provision winbind krb5-user \
      ldb-tools ldap-utils dnsutils smbclient netcat-openbsd less \
 && rm -rf /var/lib/apt/lists/*
COPY dc/provision.sh /usr/local/sbin/lab-provision
RUN bash /usr/local/sbin/lab-provision && rm /usr/local/sbin/lab-provision
# DC01's Security event log for the morning of the incident.
COPY dc/gen_seclog.py /tmp/gen_seclog.py
RUN mkdir -p /var/log/dc01 && python3 /tmp/gen_seclog.py /var/log/dc01/security.log && rm /tmp/gen_seclog.py
RUN echo 'echo "Lab ad-authentication: you are on DC01 (ridgeline.local). The Security event log is /var/log/dc01/security.log. Answers go in /root/answers.txt. Check from the host with: ./lab check ad-authentication"' >> /root/.bashrc
WORKDIR /root
# The DC itself: LDAP, Global Catalog, Kerberos and DNS in one process.
CMD ["samba", "--interactive", "--no-process-group", "--debuglevel=1"]
