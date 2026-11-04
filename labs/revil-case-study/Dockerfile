# BWD-FS01's file share, the morning after. Always a pinned tag; prefer images with arm64 builds.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq rsync \
 && rm -rf /var/lib/apt/lists/*
COPY config/make-scene.sh /tmp/make-scene.sh
RUN bash /tmp/make-scene.sh && rm /tmp/make-scene.sh
COPY case/ /root/case/
RUN mkdir -p /root/evidence \
 && echo 'echo "Lab revil-case-study: the share is /srv/share, last night'"'"'s backup /srv/backup, the logs /root/case."' >> /root/.bashrc
WORKDIR /root
CMD ["sleep", "infinity"]
