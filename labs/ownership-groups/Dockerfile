# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# Existing people: bob is leaving the team, carol is from another department.
RUN groupadd ops \
 && useradd -m -s /bin/bash -G ops bob \
 && useradd -m -s /bin/bash carol

# The shared tree, with a symlink someone planted, pointing at the shadow file.
RUN mkdir -p /srv/shared/specs/v2 \
 && echo "api draft" > /srv/shared/specs/api.md \
 && echo "v2 notes" > /srv/shared/specs/v2/notes.md \
 && ln -s /etc/shadow /srv/shared/specs/v2/latest

# Files left behind by an account that no longer exists (UID/GID 2001).
RUN mkdir -p /var/archive /opt/legacy-tool \
 && echo q1 > /var/archive/q1-export.csv \
 && echo q2 > /var/archive/q2-export.csv \
 && printf '#!/bin/sh\necho legacy\n' > /opt/legacy-tool/run.sh \
 && chown 2001:2001 /var/archive/q1-export.csv /var/archive/q2-export.csv /opt/legacy-tool/run.sh

RUN echo 'echo "Lab ownership-groups: tasks are in labs/ownership-groups/README.md. Check from the host with: ./lab check ownership-groups"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
