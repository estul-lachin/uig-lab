# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends sysstat procps pv \
 && rm -rf /var/lib/apt/lists/*

# Task 5: a renamed copy of dd that a loop keeps restarting. pv limits it to about 1 MB/s, and each run
# rewrites the same 30 MB file, so it never fills the disk.
RUN mkdir -p /usr/local/lib/.sys /var/tmp/.cache \
 && cp /usr/bin/dd /usr/local/lib/.sys/kflushd \
 && printf '%s\n' '#!/bin/sh' 'while :; do' \
      '  pv -q -L 1m /dev/urandom | /usr/local/lib/.sys/kflushd of=/var/tmp/.cache/blob bs=64k count=480 iflag=fullblock oflag=dsync status=none' \
      '  sleep 1' 'done' > /usr/local/lib/.sys/flush-loop \
 && chmod 755 /usr/local/lib/.sys/flush-loop

RUN echo 'echo "Lab disk-io: tasks are in labs/disk-io/README.md. Check from the host with: ./lab check disk-io"' >> /root/.bashrc

WORKDIR /root
CMD ["sh", "-c", "/usr/local/lib/.sys/flush-loop </dev/null >/dev/null 2>&1 & exec sleep infinity"]
