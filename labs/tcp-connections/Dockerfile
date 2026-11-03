# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends iproute2 ncat procps \
 && rm -rf /var/lib/apt/lists/*

# Task 5: a copy of ncat under a harmless-looking name, started with the container.
RUN cp "$(command -v ncat)" /usr/local/sbin/kupdated

RUN echo 'echo "Lab tcp-connections: tasks are in labs/tcp-connections/README.md. Check from the host with: ./lab check tcp-connections"' >> /root/.bashrc

WORKDIR /root
CMD ["sh", "-c", "/usr/local/sbin/kupdated -lk -p 31337 </dev/null >/dev/null 2>&1 & exec sleep infinity"]
