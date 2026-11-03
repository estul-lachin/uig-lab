# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends iproute2 iputils-ping \
 && rm -rf /var/lib/apt/lists/*

RUN echo 'echo "Lab routing-gateway: tasks are in labs/routing-gateway/README.md. Check from the host with: ./lab check routing-gateway"' >> /root/.bashrc

WORKDIR /root
# Task 5: a route someone added, sending a whole network to a host on the LAN.
CMD ["sh", "-c", "ip route add 198.51.100.0/24 via 10.253.60.66 2>/dev/null; exec sleep infinity"]
