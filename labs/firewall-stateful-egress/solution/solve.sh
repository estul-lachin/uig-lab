# Reference solution for firewall-stateful-egress.
# Writes the completed host ruleset and applies it with nft.
set -euo pipefail

cat > /root/host.nft <<'NFT'
#!/usr/sbin/nft -f
# Host firewall for workstation ws-25 (10.50.10.25) - hardened.
flush ruleset

table inet fw {
    chain input {
        type filter hook input priority 0; policy drop;

        iif "lo" accept
        ct state established,related accept
        ct state invalid drop

        # Management SSH, only from the mgmt subnet (a 5-tuple match).
        ip saddr 10.50.99.0/24 tcp dport 22 ct state new accept
    }

    chain output {
        type filter hook output priority 0; policy drop;   # default-deny egress

        oif "lo" accept
        ct state established,related accept

        # First-match: block the known C2 BEFORE the broad web allow, silently.
        ip daddr 198.51.100.66 drop

        # Blocked outbound service: reject so the app fails fast (not silent).
        tcp dport 445 reject

        # Normal egress allow-list.
        udp dport 53 accept
        tcp dport 53 accept
        tcp dport { 80, 443 } accept
    }
}
NFT

nft -f /root/host.nft
