# Reference solution for ownership-groups.
set -euo pipefail

# 1-2. Group and members
groupadd --gid 3000 devs
useradd --create-home alice
usermod --append --groups devs alice
gpasswd --delete bob devs 2>/dev/null || true

# 3. Shared file
install -m 0660 -o root -g devs /dev/null /srv/shared/notes.txt

# 4. Find and remove the planted link, then re-own the tree (-R does not follow links)
link=$(find /srv/shared -type l | head -n1)
echo "PLANTED_LINK=$link" > /root/answers.txt
rm -- "$link"
chown --recursive root:devs /srv/shared

# 5. Orphaned files
find / -xdev \( -nouser -o -nogroup \) 2>/dev/null | sort > /root/orphans.txt
xargs -r chown root:root < /root/orphans.txt
