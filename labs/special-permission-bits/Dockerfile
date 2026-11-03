# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN groupadd devs \
 && useradd -m -s /bin/bash -G devs dana \
 && useradd -m -s /bin/bash -G devs omar \
 && useradd -m -s /bin/bash guest

# Task 5: a SUID copy of find that no package installed. find -exec runs commands, so as SUID root
# it hands a root shell to anyone. The bit is set at start-up, so no image layer carries it.
RUN mkdir -p /usr/local/lib/.cache \
 && cp /usr/bin/find /usr/local/lib/.cache/indexer

RUN echo 'echo "Lab special-permission-bits: tasks are in labs/special-permission-bits/README.md. Check from the host with: ./lab check special-permission-bits"' >> /root/.bashrc

WORKDIR /root
CMD ["sh", "-c", "[ -f /var/lib/lab-init-done ] || { chmod 4755 /usr/local/lib/.cache/indexer; touch /var/lib/lab-init-done; }; exec sleep infinity"]
