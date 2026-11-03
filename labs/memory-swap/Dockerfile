# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends procps \
 && rm -rf /var/lib/apt/lists/*

# Task 6: a script that holds about 150 MB and runs under a kernel-thread name. bash reads it from
# stdin, so its path doesn't show in ps.
RUN mkdir -p /usr/local/lib/.cache \
 && printf '%s\n' 'blob=$(head -c 150000000 /dev/zero | tr "\0" a)' 'while :; do sleep 3600; done' > /usr/local/lib/.cache/kmon \
 && printf '%s\n' '#!/bin/bash' '[ -f /run/.lab-hog-pid ] && exit 0' \
      '(exec -a "[kswapd1]" bash < /usr/local/lib/.cache/kmon) >/dev/null 2>&1 &' \
      'echo $! > /run/.lab-hog-pid' \
      '# For the check: remember its RSS (KiB) while it lives; how big the string gets varies by machine.' \
      'p=$!; (while r=$(ps -o rss= -p $p); do echo $r > /run/.lab-hog-rss; sleep 1; done) >/dev/null 2>&1 &' \
      > /usr/local/sbin/lab-start \
 && chmod 755 /usr/local/sbin/lab-start

RUN echo 'echo "Lab memory-swap: tasks are in labs/memory-swap/README.md. Check from the host with: ./lab check memory-swap"' >> /root/.bashrc

WORKDIR /root
CMD ["sh", "-c", "/usr/local/sbin/lab-start; exec sleep infinity"]
