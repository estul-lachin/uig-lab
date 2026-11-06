# Reference solution for firewall-rules-nat-zones.
# Writes the completed edge ruleset and applies it with nft.
set -euo pipefail

cat > /root/edge.nft <<'NFT'
#!/usr/sbin/nft -f
# Edge firewall for site-7 - hardened.
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept

        # LAN (trusted) may reach the internet and the DMZ.
        iifname "lan0" oifname "wan0" accept
        iifname "lan0" oifname "dmz0" accept

        # DMZ (semi-trusted) may reach the internet only - never the LAN.
        iifname "dmz0" oifname "wan0" accept

        # Expose the DMZ web server: inbound HTTPS forwarded to it.
        iifname "wan0" oifname "dmz0" ip daddr 10.50.20.10 tcp dport 443 accept

        # Segmentation: the DMZ must not reach the LAN.
        iifname "dmz0" oifname "lan0" drop
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority -100;
        # Port-forward: inbound WAN :443 -> the DMZ web server (DNAT).
        iifname "wan0" tcp dport 443 dnat to 10.50.20.10:443
    }
    chain postrouting {
        type nat hook postrouting priority 100;
        # Many internal hosts share the one public IP on the way out (SNAT/PAT).
        oifname "wan0" masquerade
    }
}
NFT

nft -f /root/edge.nft
