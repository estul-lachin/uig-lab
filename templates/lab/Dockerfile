# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# Install what the lab needs:
# RUN apt-get update \
#  && apt-get install -y --no-install-recommends <packages> \
#  && rm -rf /var/lib/apt/lists/*

RUN echo 'echo "Lab __NAME__: tasks are in labs/__NAME__/README.md. Check from the host with: ./lab check __NAME__"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
