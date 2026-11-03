# Reference solution for dns-resolution.
set -euo pipefail

# 1. Configured nameservers
grep ^nameserver /etc/resolv.conf | awk '{print $2}' > /root/ns.txt

# 2. Lookups with dig
dig +short portal.corp.lab A > /root/a_portal.txt
dig +short -x 10.20.0.15 > /root/ptr.txt

# 3. Local override (as analyst: echo ... | sudo tee -a /etc/hosts)
echo '10.99.99.99 test.corp.lab' | su analyst -c 'sudo tee -a /etc/hosts' >/dev/null

# 4. Resolver order
grep ^hosts /etc/nsswitch.conf > /root/nss_hosts.txt

# 5. Hosts-file hijack
{
  echo "HIJACKED_NAME=updates.corp.lab"
  echo "ROGUE_IP=$(getent hosts updates.corp.lab | awk '{print $1}')"
  echo "REAL_IP=$(dig +short updates.corp.lab A | head -n1)"
} > /root/findings.txt
grep -v 'updates\.corp\.lab' /etc/hosts > /tmp/hosts.new
cat /tmp/hosts.new > /etc/hosts
rm -f /tmp/hosts.new
