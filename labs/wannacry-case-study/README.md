# wannacry-case-study

## Concepts

**WannaCry** (WannaCrypt, WCry) hit Windows systems worldwide from 12 May 2017. It encrypted files
and demanded US$300–600 in Bitcoin, with a countdown. Two things made it the classic case:
- **It was a worm.** It didn't wait for anyone to click. It used **EternalBlue**, an exploit for
  SMBv1 on TCP 445 that the NSA had developed, which leaked in April 2017. It then installed the
  **DoublePulsar** backdoor to load its payload, and every new victim started scanning for more, inside
  the network and out on the internet.
- **The patch already existed.** Microsoft's MS17-010 came out on 14 March 2017, two months earlier.
  Unpatched, legacy and SMBv1-enabled machines did the rest.

Within days it reached 150+ countries and hundreds of thousands of computers. The UK's NHS diverted
ambulances; Telefónica, FedEx, Renault and Deutsche Bahn were hit. The US, UK and others attributed
it to North Korea's **Lazarus Group** (MITRE G0032).

**The kill switch.** Before doing anything, the malware looked up a long, unregistered domain. If the
lookup *succeeded*, it quit. A researcher registered the domain, and from then on new infections of
that variant stopped themselves. Its command and control was otherwise minimal: Tor for the payment
side, and no operator steering it.

What victims saw:
- Files renamed to `.WNCRY`.
- A note, `@Please_Read_Me@.txt`.
- The red "Wana Decrypt0r 2.0" window.
- A changed wallpaper.

By the time anyone sees the note, encryption is over.

**Why it maps awkwardly to the Cyber Kill Chain**: there is no human doing reconnaissance or delivery.
The worm scans, delivers and moves laterally by itself. Network controls matter more than awareness
training here:
- Patch.
- Turn off SMBv1.
- Block 445 and 139 at the edge and between zones.
- Segment.

**SMB in one paragraph**: Windows file sharing. SMBv1 (dialect "NT LM 0.12") is from the 1990s and has
no place on a modern network; SMB2 and SMB3 replace it. It runs directly on TCP 445, and in the old
NetBIOS way on TCP 139. On Linux, **Samba** speaks it. `server min protocol` sets the oldest dialect
it accepts, `smb ports` the ports it listens on, and `testparm -s` shows the effective settings.

**Zeek logs** are tab-separated, one connection or one DNS lookup per line, with a `#fields` header.
`conn_state` tells you how a TCP connection went:

| `conn_state` | Meaning |
|---|---|
| `SF` | Completed normally |
| `S0` | A connection attempt that was never answered (filtered) |
| `REJ` | Refused |
| `RSTO` | The originator aborted (reset) it |

## Tasks

Start the lab with `./lab up wannacry-case-study`, open a shell with `./lab shell wannacry-case-study`.
You are root on **AVW-SRV11** (10.253.82.10), a legacy file server at Alder Valley Water (fictional),
on the plant LAN 10.253.82.0/24. Write `KEY=value` answers to `/root/case/answers.txt`.

1. **WannaCry in brief.** `KILL_SWITCH=<what stopped it>`, `EXPLOIT=` and `BACKDOOR=<its two tools>`,
   `EXTENSION=<what it appended to files>`, `RANSOM_NOTE=<the note's file name>`.
2. **SMB exposure on the plant LAN**, before you change anything:

   ```
   SMB_HOSTS=<every address on 10.253.82.0/24 listening on 445, comma-separated>
   SMB1_HOSTS=<those that still accept SMBv1>
   ```

3. **Harden this server.** On AVW-SRV11:
   - Refuse SMBv1 permanently (in the configuration).
   - Stop listening on 139.
   - Keep the `exports` share working over SMB3 for user `ops` (password `Lab-Smb-2026`).
4. **The outbreak.** `/root/case` has `conn.log` and `dns.log` from the office network (10.60.0.0/16) on
   the morning the worm arrived, and `inventory.csv` with each host's MS17-010 status:

   ```
   ENTRY_IP=<where the worm came from>
   PATIENT_ZERO=<the first internal host infected>
   ENCRYPTED_HOSTS=<how many infected hosts went on to encrypt>
   STOPPED_BY_SINKHOLE=<how many infected hosts stopped themselves>
   FIREWALLED=<unpatched hosts the worm tried but could not reach, comma-separated>
   NEVER_SCANNED=<unpatched hosts it never even tried>
   ```

   Every infected host looks up the same domain before acting. Find it.

Check your work from the host: `./lab check wannacry-case-study`

<details>
<summary>Hints</summary>

- `nmap -n -p 445 --open 10.253.82.0/24`, then `nmap -p 445 --script smb-protocols <host>`
- `smbclient -L //<host> -N -m NT1 --option="client min protocol=NT1"` is another way to ask about SMBv1
- `/etc/samba/smb.conf`; `testparm -s`; `smbcontrol smbd reload-config` re-reads most settings, but a
  port change needs smbd restarted: `pkill smbd; smbd -D`
- `awk -F'\t' '!/^#/ && $6 == 445'` filters conn.log; column 3 is the source, 5 the destination
- In dns.log, which query do only some hosts make, once each?
- Join inventory.csv's `missing` hosts with the `conn_state` of connections to their 445

</details>

## My notes

<!-- Screenshots: ./lab shot wannacry-case-study ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [lockbit-case-study](../lockbit-case-study/), [conti-case-study](../conti-case-study/) and
  [blackcat-case-study](../blackcat-case-study/): human-operated ransomware, for contrast
- [tcp-connections](../tcp-connections/): `ss` and connection states
- [routing-gateway](../routing-gateway/): segmenting networks
- CISA alert TA17-132A, Microsoft bulletin MS17-010, MITRE ATT&CK S0366 and G0032
