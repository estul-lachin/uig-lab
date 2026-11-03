# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends procps sysstat \
 && rm -rf /var/lib/apt/lists/*

# Task 5: a copy of yes under a known miner's name, restarted by a loop. It burns CPU for half a second,
# then rests half a second, so it averages about half a core.
RUN mkdir -p /usr/local/lib/.x \
 && cp /usr/bin/yes /usr/local/lib/.x/kdevtmpfsi \
 && printf '%s\n' '#!/bin/sh' 'while :; do' '  timeout 0.5 /usr/local/lib/.x/kdevtmpfsi >/dev/null' '  sleep 0.5' 'done' > /usr/local/lib/.x/kinsing \
 && chmod 755 /usr/local/lib/.x/kinsing

RUN echo 'echo "Lab cpu-load: tasks are in labs/cpu-load/README.md. Check from the host with: ./lab check cpu-load"' >> /root/.bashrc

WORKDIR /root
CMD ["sh", "-c", "/usr/local/lib/.x/kinsing </dev/null >/dev/null 2>&1 & exec sleep infinity"]
