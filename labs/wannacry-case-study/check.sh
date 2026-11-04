# Checks for wannacry-case-study (see templates/lab/check.sh for the rules).

C=/root/case
A=$C/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]" | tr A-Z a-z; }
_in() { local v; v=$(_kv $A "$1"); [ -n "$v" ] && for x in $2; do [ "$v" = "$x" ] && return 0; done; return 1; }
_set() { _kv $A "$1" | tr "," "\n" | grep . | sort -u | paste -sd,; }
_nt1() { smbclient -L //127.0.0.1 -N -m NT1 --option="client min protocol=NT1" >/dev/null 2>&1; }
_smb3() { smbclient //127.0.0.1/exports -U "ops%Lab-Smb-2026" -m SMB3 -c ls >/dev/null 2>&1; }

section "1. WannaCry in brief"
check "KILL_SWITCH names the mechanism that stopped it" '_in KILL_SWITCH "killswitch kill-switch"' "A domain the malware checked before it did anything"
check "EXPLOIT and BACKDOOR are the two tools it used" '[ "$(printf "%s\n" "$(_kv $A EXPLOIT)" "$(_kv $A BACKDOOR)" | sort | paste -sd,)" = doublepulsar,eternalblue ]' \
  "The leaked NSA exploit, and the implant it installed"
check "EXTENSION is what it appended to files" '_in EXTENSION ".wncry wncry"' "Five letters starting with W"
check "RANSOM_NOTE is the note's file name" '_in RANSOM_NOTE "@please_read_me@.txt"' "It starts and ends with @"

section "2. SMB exposure on the plant LAN (before you change anything)"
check "SMB_HOSTS lists every host on 10.253.82.0/24 that listens on 445" '[ "$(_set SMB_HOSTS)" = 10.253.82.10,10.253.82.11,10.253.82.12 ]' \
  "nmap -p 445 --open 10.253.82.0/24; comma-separated"
check "SMB1_HOSTS lists those that still accept SMBv1" '[ "$(_set SMB1_HOSTS)" = 10.253.82.10,10.253.82.12 ]' \
  "nmap --script smb-protocols; look for NT LM 0.12"

section "3. Harden this server"
check "Samba is running and the exports share works over SMB3 as ops" 'pgrep -x smbd >/dev/null && _smb3' \
  "Do not break the service: smbclient //127.0.0.1/exports -U ops -m SMB3"
check "SMBv1 is refused" 'pgrep -x smbd >/dev/null && _smb3 && ! _nt1' "server min protocol in smb.conf, then reload"
check "...and that is in smb.conf, not only in memory" 'case "$(testparm -s --parameter-name="server min protocol" 2>/dev/null | tr a-z A-Z)" in SMB2*|SMB3*) true ;; *) false ;; esac' \
  "testparm -s --parameter-name=\"server min protocol\" shows the effective value"
check "Nothing listens on 139 (NetBIOS session) any more, 445 still does" '[ -n "$(ss -Htln "sport = :445")" ] && [ -z "$(ss -Htln "sport = :139")" ]' \
  "smb ports; restart smbd for a port change"

section "4. The outbreak at Alder Valley Water"
check "ENTRY_IP is where the worm came from" '_in ENTRY_IP 203.0.113.130' "The first connection to 445 from outside 10.60.0.0/16"
check "PATIENT_ZERO is the first internal host infected" '_in PATIENT_ZERO "10.60.2.15 avw-srv15"' "Its target"
check "ENCRYPTED_HOSTS is how many hosts went on to encrypt" '_in ENCRYPTED_HOSTS 10' "Kill-switch lookups that got NXDOMAIN"
check "STOPPED_BY_SINKHOLE is how many infected hosts stopped themselves" '_in STOPPED_BY_SINKHOLE 8' "Lookups that got an answer"
check "FIREWALLED lists the unpatched hosts a firewall saved" '[ "$(_set FIREWALLED)" = 10.60.3.5,10.60.3.6 ]' \
  "Unpatched in inventory.csv, attempted in conn.log, never answered (S0)"
check "NEVER_SCANNED lists the unpatched hosts that were just lucky" '[ "$(_set NEVER_SCANNED)" = 10.60.1.40 ]' "Unpatched, and no connection to their 445 at all"
