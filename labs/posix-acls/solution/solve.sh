# Reference solution for posix-acls.
set -euo pipefail
R=/srv/casework

# 1. Target directory
mkdir -p "$R"
chown root:root "$R"
chmod 0750 "$R"

# 2-3. Access ACL and default ACL for auditor
setfacl --modify user:auditor:r-x "$R"
setfacl --default --modify user:auditor:r-- "$R"

# 4. Verify
getfacl --absolute-names "$R" > /root/acl.txt

# 5-6. Answers and the exposure
{
  echo "FINN_EFFECTIVE=$(getfacl -p /srv/hr/budget.csv | awk -F'#effective:' '/^user:finn:/ {print $2}')"
  echo "FINN_CAN_WRITE=no"
  echo "EXPOSED_FILE=/srv/hr/salaries.csv"
  echo "EXPOSED_TO=intern"
} > /root/answers.txt
setfacl --remove user:intern /srv/hr/salaries.csv /srv/hr
