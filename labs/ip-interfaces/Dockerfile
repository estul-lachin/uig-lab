# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends iproute2 iputils-ping \
 && rm -rf /var/lib/apt/lists/*

# Runs at container start: interface names are assigned at runtime, so the setup finds them by address.
RUN cat > /usr/local/sbin/lab-net-init <<'SH' && chmod 755 /usr/local/sbin/lab-net-init
#!/bin/sh
by_ip() { ip -o -4 addr show | awk -v ip="$1" '$4 ~ "^"ip"/" {print $2}' | head -n1; }
lan=$(by_ip 10.253.70.10)
mgmt=$(by_ip 10.253.71.10)
{
  echo "# Asset record for edge-02: the only interfaces that should carry an address"
  echo "lo    127.0.0.1"
  echo "$lan  $(cat /sys/class/net/$lan/address)  10.253.70.10 10.253.70.99  (lan)"
  echo "$mgmt  $(cat /sys/class/net/$mgmt/address)  10.253.71.10  (management)"
} > /root/asset-record.txt
ip addr add 10.253.70.99/24 dev "$lan"
ip link set "$mgmt" mtu 1400
ip link set "$mgmt" down
ip link set lo down
ip link add upd0 type dummy && ip addr add 10.66.0.1/24 dev upd0 && ip link set upd0 up
SH

RUN echo 'echo "Lab ip-interfaces: tasks are in labs/ip-interfaces/README.md. Check from the host with: ./lab check ip-interfaces"' >> /root/.bashrc

WORKDIR /root
CMD ["sh", "-c", "/usr/local/sbin/lab-net-init >/dev/null 2>&1; exec sleep infinity"]
