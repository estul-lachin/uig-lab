# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN mkdir -p /root/scripts

RUN echo 'echo "Lab bash-conditionals: tasks are in labs/bash-conditionals/README.md. Check from the host with: ./lab check bash-conditionals"' >> /root/.bashrc

WORKDIR /root/scripts
CMD ["sleep", "infinity"]
