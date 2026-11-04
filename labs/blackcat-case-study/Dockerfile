# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*

COPY case/ /root/case/
RUN echo 'echo "Lab blackcat-case-study: the evidence is in /root/case; tasks in labs/blackcat-case-study/README.md."' >> /root/.bashrc

WORKDIR /root/case
CMD ["sleep", "infinity"]
