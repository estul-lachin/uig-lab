# Reference solution for ad-authentication: knowledge answers, the SPN read live, the log triaged.
set -eu
umask 022
LOG=/var/log/dc01/security.log
spn=$(samba-tool spn list svc_sql 2>/dev/null | grep -oE 'MSSQLSvc/[^ ]*' | grep -v ':' | head -n1)
attacker=$(grep "EventID=4740" "$LOG" | grep -oE 'IpAddress=[0-9.]+' | cut -d= -f2 | head -n1)
brute=$(grep "EventID=4625" "$LOG" | grep "IpAddress=$attacker" | grep -oE 'TargetUser=[^ ]+' | sort | uniq -c | sort -rn | head -n1 | awk '{print $1}' | sed 's/TargetUser=//')
bacct=$(grep "EventID=4625" "$LOG" | grep "IpAddress=$attacker" | grep -oE 'TargetUser=[^ ]+' | sort | uniq -c | sort -rn | head -n1 | sed 's/.*TargetUser=//')
bcount=$(grep "EventID=4625" "$LOG" | grep "$bacct" | grep -c "IpAddress=$attacker")
lockout=$(grep "EventID=4740" "$LOG" | grep -oE 'TargetUser=[^ ]+' | head -n1 | sed 's/TargetUser=//')
kroast=$(grep "EventID=4769" "$LOG" | grep -c MSSQLSvc)
kenc=$(grep "EventID=4769" "$LOG" | grep MSSQLSvc | grep -oE 'TicketEncryption=[^ ]+' | sort -u | head -n1 | cut -d= -f2)
pth=$(grep "EventID=4624" "$LOG" | grep "AuthPackage=NTLM" | grep "IpAddress=$attacker" | grep -oE 'TargetUser=[^ ]+' | head -n1 | sed 's/TargetUser=//')
{
  echo "AUTH_DEFAULT=Kerberos"
  echo "LEGACY_PROTOCOL=NTLM"
  echo "TICKET_CMD=klist"
  echo "EVT_LOGON_SUCCESS=4624"
  echo "EVT_LOGON_FAIL=4625"
  echo "EVT_TGT=4768"
  echo "EVT_TGS=4769"
  echo "EVT_LOCKOUT=4740"
  echo "RDP_LOGON_TYPE=10"
  echo "KERBEROASTABLE_ACCOUNT=svc_sql"
  echo "SPN=$spn"
  echo "ATTACKER_IP=$attacker"
  echo "BRUTE_ACCOUNT=$bacct"
  echo "BRUTE_FAILS=$bcount"
  echo "LOCKOUT_ACCOUNT=$lockout"
  echo "KROAST_COUNT=$kroast"
  echo "KROAST_ENC=$kenc"
  echo "PTH_ACCOUNT=$pth"
} > /root/answers.txt
