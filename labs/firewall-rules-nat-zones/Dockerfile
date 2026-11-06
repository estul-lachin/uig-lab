# The edge firewall. Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends nftables iproute2 \
 && rm -rf /var/lib/apt/lists/*

# The ruleset the learner completes (a hardening template, not the solution).
COPY skel/edge.nft /root/edge.nft
RUN chmod 644 /root/edge.nft

RUN echo 'echo "Lab firewall-rules-nat-zones: edit /root/edge.nft, apply with: nft -f /root/edge.nft. Check from the host with: ./lab check firewall-rules-nat-zones"' >> /root/.bashrc

WORKDIR /root
# Create the three zone interfaces (dummy links) so the rules apply to real interfaces,
# then idle. The ruleset starts empty - the learner builds and applies it.
CMD ["sh", "-c", "\
ip link add wan0 type dummy 2>/dev/null; ip addr add 203.0.113.10/24 dev wan0 2>/dev/null; ip link set wan0 up; \
ip link add lan0 type dummy 2>/dev/null; ip addr add 10.50.10.1/24 dev lan0 2>/dev/null; ip link set lan0 up; \
ip link add dmz0 type dummy 2>/dev/null; ip addr add 10.50.20.1/24 dev dmz0 2>/dev/null; ip link set dmz0 up; \
exec sleep infinity"]
