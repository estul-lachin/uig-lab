# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl procps e2fsprogs \
 && rm -rf /var/lib/apt/lists/*

# The file share: 120 small documents in three departments.
RUN for d in finance hr ops; do mkdir -p /srv/share/$d; for i in $(seq -w 1 40); do \
      printf '%s document %s\nowner: %s-team\n%s\n' "$d" "$i" "$d" "$(head -c 300 /dev/urandom | base64 -w 76)" > /srv/share/$d/$d-$i.txt; \
    done; done \
 && mkdir -p /var/log && echo "$(date -u +%FT%TZ) fs-audit started" > /var/log/fs-audit.log

# Last night's ordinary (mutable) backup. /backup is a volume: Docker copies this into it on first start.
RUN mkdir -p /backup/nightly /backup/immutable \
 && tar -C /srv -czf /backup/nightly/share-2026-11-02.tar.gz share

# The drill: a simulated encryptor, started by hand in task 2. It only touches /srv/share and /backup.
COPY drill/ /opt/drill/
RUN chmod 755 /opt/drill/start-incident.sh /opt/drill/lockerd.sh

RUN echo 'echo "Lab ransomware-drill: tasks are in labs/ransomware-drill/README.md. Check from the host with: ./lab check ransomware-drill"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
