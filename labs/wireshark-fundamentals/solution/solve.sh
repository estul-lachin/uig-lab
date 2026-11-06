# Reference solution for wireshark-fundamentals.
# Derives every answer from the capture with tshark, then writes /root/answers.txt.
set -euo pipefail
umask 022

CAP=/opt/intro/lab-capture.pcapng
CLIENT=10.10.10.50

# Server the client logs in to: destination of the FTP login.
server_ip=$(tshark -r "$CAP" -Y 'ftp.request.command=="USER"' -T fields -e ip.dst 2>/dev/null | head -n1)

# TELNET username/password: the two things the client typed into the stream, in order.
mapfile -t tln < <(
  tshark -r "$CAP" -Y "telnet && ip.src==$CLIENT" -T fields -e telnet.data 2>/dev/null \
    | tr -d '\r' | sed 's/\\r//g; s/\\n//g' | grep .
)
telnet_user=${tln[0]:-}
telnet_pass=${tln[1]:-}

# Anonymous FTP password: the argument of the PASS command.
ftp_pass=$(tshark -r "$CAP" -Y 'ftp.request.command=="PASS"' -T fields -e ftp.request.arg 2>/dev/null | head -n1)

# Host targeted by the plain-HTTP recon.
http_host=$(tshark -r "$CAP" -Y 'http.request' -T fields -e http.host 2>/dev/null | sort -u | grep . | head -n1)

cat > /root/answers.txt <<EOF
# Wireshark Fundamentals - answers
BYTES_PANE=Packet Bytes
PROTOCOL=telnet
SERVER_IP=$server_ip
TELNET_USER=$telnet_user
TELNET_PASS=$telnet_pass
FTP_PASS=$ftp_pass
FILTER_PASSWORD=frame contains "password"
HTTP_HOST_FIELD=http.host
HTTP_HOST=$http_host
EOF
