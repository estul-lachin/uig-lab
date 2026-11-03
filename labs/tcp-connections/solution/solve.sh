# Reference solution for tcp-connections.
set -euo pipefail
cd /root

# 1. Listening sockets
ss -tlnp > /root/listen.txt

# 2. A listener that survives
nohup setsid ncat -lk -p 9001 </dev/null >/dev/null 2>&1 & disown

# 3. Send a line
nohup setsid ncat -l -p 9002 </dev/null >/root/recv.txt 2>&1 & disown
sleep 0.5
echo "case 4471 opened" | ncat --send-only 127.0.0.1 9002
sleep 0.5

# 4. Hold a connection open
nohup setsid ncat -lk --no-shutdown -p 9003 </dev/null >/dev/null 2>&1 & disown
sleep 0.5
nohup setsid ncat --no-shutdown 127.0.0.1 9003 </dev/null >/dev/null 2>&1 & disown
sleep 0.5
ss -H -tn state established '( sport = :9003 or dport = :9003 )' | wc -l > /root/est_count.txt

# 5. The odd listener
pid=$(ss -Htlnp 'sport = :31337' | grep -o 'pid=[0-9]*' | head -n1 | cut -d= -f2)
{
  echo "ODD_PORT=31337"
  echo "ODD_PROCESS=$(ss -Htlnp 'sport = :31337' | grep -o '(("[^"]*"' | head -n1 | tr -d '("')"
  echo "ODD_PATH=$(readlink /proc/$pid/exe)"
} > /root/findings.txt
kill "$pid"
sleep 0.5
