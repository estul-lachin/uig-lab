# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# /root is 700 by default; 711 lets operator2 reach /root/scripts (task 2 tests as that user).
RUN mkdir -p /root/scripts \
 && chmod 711 /root \
 && useradd -m -s /bin/bash operator2

RUN echo 'echo "Lab bash-functions: tasks are in labs/bash-functions/README.md. Check from the host with: ./lab check bash-functions"' >> /root/.bashrc

WORKDIR /root/scripts
CMD ["sleep", "infinity"]
