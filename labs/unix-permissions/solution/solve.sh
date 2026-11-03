# Reference solution for unix-permissions.
set -euo pipefail
K=/home/kai

# 1. Secret file, private from the moment it exists
install -m 600 -o kai -g kai /dev/null $K/secret.txt

# 2. Team directory
install -d -m 750 -o kai -g crew $K/team

# 3. Script, made executable symbolically
install -d -m 755 -o kai -g crew $K/bin
printf '#!/bin/bash\necho hi\n' > $K/bin/hello.sh
chown kai:crew $K/bin/hello.sh
chmod 644 $K/bin/hello.sh
chmod u+x,g+x $K/bin/hello.sh

# 4. The project tree
chmod -R o-rwx,g+rX $K/project

# 5. umask for kai's login shells
echo 'umask 027' >> $K/.profile

# 6. Answers (each one can be tried with su zoe -c '...')
cat > /root/answers.txt <<'A'
LISTONLY_LS=yes
LISTONLY_CAT=no
DROPBOX_LS=no
DROPBOX_CREATE=yes
DROPBOX_DELETE=yes
A
