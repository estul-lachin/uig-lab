# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends acl \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd hrteam && groupadd finance-ro \
 && useradd -m -s /bin/bash auditor \
 && useradd -m -s /bin/bash intern \
 && useradd -m -s /bin/bash -G hrteam hana \
 && useradd -m -s /bin/bash finn

# The HR share for tasks 5 and 6. The files are built into the image; the ACLs are set at start-up
# because image layers don't keep ACL xattrs: one ACL that belongs, one capped by the mask, one that shouldn't exist.
RUN mkdir -p /srv/hr/policies \
 && echo "name,salary" > /srv/hr/salaries.csv \
 && echo "travel policy" > /srv/hr/policies/travel.txt \
 && echo "q3 budget" > /srv/hr/budget.csv \
 && chown -R root:hrteam /srv/hr && chmod -R u=rwX,g=rX,o= /srv/hr \
 && printf '%s\n' '#!/bin/sh' \
      '[ -f /var/lib/lab-acl-done ] && exit 0' \
      'setfacl -m g:finance-ro:rx /srv/hr/policies' \
      'setfacl -m u:finn:x /srv/hr' \
      'setfacl -m u:finn:rw /srv/hr/budget.csv && setfacl -m m::r /srv/hr/budget.csv' \
      'setfacl -m u:intern:rx /srv/hr && setfacl -m u:intern:rw /srv/hr/salaries.csv' \
      'touch /var/lib/lab-acl-done' \
      > /usr/local/sbin/lab-acl-init \
 && chmod 755 /usr/local/sbin/lab-acl-init

RUN echo 'echo "Lab posix-acls: tasks are in labs/posix-acls/README.md. Check from the host with: ./lab check posix-acls"' >> /root/.bashrc

WORKDIR /root
CMD ["sh", "-c", "/usr/local/sbin/lab-acl-init; exec sleep infinity"]
