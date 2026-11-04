# Reference solution for wannacry-case-study.
set -eu
umask 022
cd /root/case

# 2. The audit, before anything changes
smb=$(nmap -n -Pn -p 445 --open -oG - 10.253.82.0/24 | awk '/445\/open/ {print $2}' | sort -t. -k4 -n | paste -sd,)
smb1=$(for h in $(echo "$smb" | tr , " "); do
  nmap -n -Pn -p 445 --script smb-protocols "$h" | grep -q "SMBv1" && echo "$h"; done | paste -sd,)

# 3. Harden: SMB2 minimum, 445 only; ports need a restart
sed -i 's/^\(\s*server min protocol\s*=\s*\).*/\1SMB2_02/' /etc/samba/smb.conf
grep -q '^\s*smb ports' /etc/samba/smb.conf || sed -i 's/^\[global\]$/[global]\n   smb ports = 445/' /etc/samba/smb.conf
pkill -x smbd || true
for _ in $(seq 1 20); do pgrep -x smbd >/dev/null || break; sleep 0.5; done
smbd -D
for _ in $(seq 1 20); do [ -n "$(ss -Htln 'sport = :445')" ] && break; sleep 0.5; done

# 4. The logs
entry=$(awk -F'\t' '!/^#/ && $6 == 445 && $3 !~ /^10\.60\./ {print $3; exit}' conn.log)
p0=$(awk -F'\t' -v e="$entry" '!/^#/ && $3 == e {print $5; exit}' conn.log)
enc=$(awk -F'\t' '!/^#/ && $3 ~ /update\.example$/ && $4 == "NXDOMAIN"' dns.log | wc -l)
stop=$(awk -F'\t' '!/^#/ && $3 ~ /update\.example$/ && $4 == "NOERROR"' dns.log | wc -l)
fw=""; lucky=""
for ip in $(awk -F, '$4 == "missing" {print $1}' inventory.csv); do
  states=$(awk -F'\t' -v d="$ip" '!/^#/ && $5 == d && $6 == 445 {print $8}' conn.log | sort -u | paste -sd,)
  [ -z "$states" ] && lucky="$lucky,$ip"
  [ "$states" = S0 ] && fw="$fw,$ip"
done

{
  echo "KILL_SWITCH=kill switch"
  echo "EXPLOIT=EternalBlue"
  echo "BACKDOOR=DoublePulsar"
  echo "EXTENSION=.WNCRY"
  echo "RANSOM_NOTE=@Please_Read_Me@.txt"
  echo "SMB_HOSTS=$smb"
  echo "SMB1_HOSTS=$smb1"
  echo "ENTRY_IP=$entry"
  echo "PATIENT_ZERO=$p0"
  echo "ENCRYPTED_HOSTS=$enc"
  echo "STOPPED_BY_SINKHOLE=$stop"
  echo "FIREWALLED=${fw#,}"
  echo "NEVER_SCANNED=${lucky#,}"
} > answers.txt
