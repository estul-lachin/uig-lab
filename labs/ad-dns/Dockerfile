# DC01: a real Active Directory domain controller (Samba 4 AD DC) and its AD-integrated DNS, provisioned at build time.
# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends samba samba-ad-dc samba-ad-provision winbind krb5-user \
      ldb-tools ldap-utils dnsutils smbclient netcat-openbsd less \
 && rm -rf /var/lib/apt/lists/*
COPY dc/provision.sh /usr/local/sbin/lab-provision
RUN bash /usr/local/sbin/lab-provision && rm /usr/local/sbin/lab-provision
# The DC's DNS query log for the morning of the incident.
COPY dc/gen_dnslog.py /tmp/gen_dnslog.py
RUN mkdir -p /var/log/dns && python3 /tmp/gen_dnslog.py /var/log/dns/queries.log && rm /tmp/gen_dnslog.py
COPY dc/plant.sh /usr/local/sbin/lab-plant
COPY dc/start.sh /usr/local/sbin/lab-start
RUN echo 'echo "Lab ad-dns: you are on DC01 (ridgeline.local). The DNS query log is /var/log/dns/queries.log. Answers go in /root/answers.txt. Check from the host with: ./lab check ad-dns"' >> /root/.bashrc
WORKDIR /root
# First-start setup, then the DC itself: LDAP, Kerberos and DNS in one process tree.
CMD ["bash", "/usr/local/sbin/lab-start"]
