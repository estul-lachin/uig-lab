# Reference solution for tshark-tcp-smb.
# Derives the capture-specific answers with tshark, then writes /root/answers.txt.
set -euo pipefail
umask 022

CAP=/opt/captures/slow-smb.pcapng

# File server: destination of the SMB2 Tree Connect request.
server=$(tshark -r "$CAP" -Y 'smb2.cmd==3 && smb2.flags.response==0' -T fields -e ip.dst 2>/dev/null | grep . | head -n1)

# Share the client mounts: smb2.tree is \\server\share; the share is the last component.
tree=$(tshark -r "$CAP" -T fields -e smb2.tree 2>/dev/null | sort -u | grep . | head -n1)
share=${tree##*\\}

# Folder path opened inside the share: the shortest smb2.filename (the directory itself).
folder=$(tshark -r "$CAP" -Y smb2.filename -T fields -e smb2.filename 2>/dev/null \
           | sort -u | grep . | awk '{ print length, $0 }' | sort -n | head -n1 | cut -d' ' -f2-)

{
  printf '%s\n' '# TShark TCP + SMB analysis - answers'
  printf 'READ_FLAG=%s\n'   '-r'
  printf 'FILTER_FLAG=%s\n' '-Y'
  printf 'FIELDS_MODE=%s\n' 'fields'
  printf 'LOSS_FIELD=%s\n'  'tcp.analysis.duplicate_ack'
  printf 'CONDITION=%s\n'   'packet loss'
  printf 'PROTOCOL=%s\n'    'SMB2'
  printf 'SERVER_IP=%s\n'   "$server"
  printf 'SHARE=%s\n'       "$share"
  printf 'FOLDER_PATH=%s\n' "$folder"
  printf 'EXPORT_FLAG=%s\n' '--export-objects'
} > /root/answers.txt
