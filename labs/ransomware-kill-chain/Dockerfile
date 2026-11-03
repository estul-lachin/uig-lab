# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

COPY intel/ /root/intel/
RUN mkdir -p /root/intel/iocs \
 && echo 'echo "Lab ransomware-kill-chain: the case is in /root/intel; tasks in labs/ransomware-kill-chain/README.md."' >> /root/.bashrc

WORKDIR /root/intel
CMD ["sleep", "infinity"]
