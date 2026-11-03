# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# Tools the tasks need; the package lists are removed again so task 4 has to run apt-get update itself.
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-client procps \
 && rm -rf /var/lib/apt/lists/*

# A regular user and the intentionally broken script for task 5.
RUN useradd -m -s /bin/bash student \
 && printf '%s\n' '#!/bin/bash' 'echo "Welcome aboard!"' 'mkdir /no/such/parent/dir' > /home/student/welcome.sh \
 && chmod 755 /home/student/welcome.sh \
 && chown student:student /home/student/welcome.sh

RUN echo 'echo "Lab linux-server-setup: tasks are in labs/linux-server-setup/README.md. Check from the host with: ./lab check linux-server-setup"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
