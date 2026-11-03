# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends nano vim procps \
 && rm -rf /var/lib/apt/lists/*

# Files to edit and combine.
RUN mkdir -p /root/work \
 && printf '%s\n' \
      '2026-10-30T09:12:01 GET http://203.0.113.50/stage1.bin client=10.0.4.17' \
      '2026-10-30T09:12:44 GET http://198.51.100.7/update.json client=10.0.4.22' \
      '2026-10-30T09:13:01 POST http://203.0.113.50/beacon client=10.0.4.17 ref=203.0.113.50' \
      '2026-10-30T09:14:01 POST http://203.0.113.50/beacon client=10.0.4.17' \
      > /root/work/proxy.log \
 && printf '%s\n' \
      '# booking service' \
      'environment=staging' \
      'db_host=db.staging.internal' \
      'cache_host=cache.staging.internal' \
      'log_level=info' \
      > /root/work/app.conf \
 && printf '%s\n' '09:12 stage1.bin downloaded' '09:13 first beacon' > /root/work/part1.log \
 && printf '%s\n' '09:40 host isolated' '10:05 image taken' > /root/work/part2.log

RUN echo 'echo "Lab linux-file-editing: tasks are in labs/linux-file-editing/README.md. Check from the host with: ./lab check linux-file-editing"' >> /root/.bashrc

WORKDIR /root/work
CMD ["sleep", "infinity"]
