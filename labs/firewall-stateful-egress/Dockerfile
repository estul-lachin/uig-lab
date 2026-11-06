# The workstation whose host firewall we harden. Pinned tag (never latest); prefer arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends nftables iproute2 \
 && rm -rf /var/lib/apt/lists/*

# The ruleset the learner completes (a hardening template, not the solution).
COPY skel/host.nft /root/host.nft
RUN chmod 644 /root/host.nft

RUN echo 'echo "Lab firewall-stateful-egress: edit /root/host.nft, apply with: nft -f /root/host.nft. Check from the host with: ./lab check firewall-stateful-egress"' >> /root/.bashrc

WORKDIR /root
# Give the host its LAN address, then idle. The ruleset starts empty - the learner builds it.
CMD ["sh", "-c", "\
ip link add net0 type dummy 2>/dev/null; ip addr add 10.50.10.25/24 dev net0 2>/dev/null; ip link set net0 up; \
exec sleep infinity"]
