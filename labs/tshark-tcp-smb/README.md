# tshark-tcp-smb

## Concepts

**TShark is Wireshark on the command line.** Each output line maps onto the Wireshark columns
(number, time, source, destination, protocol, length, info), and because the fields are plain text
you can pipe them into `grep`, `wc`, `sort` and friends. The options you lean on constantly:

- `-r file.pcapng` reads a saved capture (without it, TShark captures live like `tcpdump`).
- `-Y '<filter>'` applies a Wireshark **display filter** (`smb2`, `tcp.analysis.duplicate_ack`, …).
- `-T fields -e <field>` prints only the fields you name, one column each.

**Diagnosing "slow" — TCP expert analysis.** Wireshark/TShark flag TCP health problems through the
`tcp.analysis.*` fields: `retransmission` and `fast_retransmission` (a segment had to be resent),
`duplicate_ack` (the receiver keeps re-ACKing the last in-order byte because one is missing — the
classic packet-loss signature), `lost_segment`, and `zero_window` (a full receive buffer, a
*different* cause). A flood of duplicate ACKs plus retransmissions says the network is **dropping
segments**: throughput collapses because the data keeps having to be sent again.

**Reading SMB2 identity.** A Windows file server publishes a folder as a **share**, reached by a UNC
path `\\server\share`. To use it the client does a *Tree Connect* (like mapping a drive `Z:`), and
Wireshark puts the mounted share in **`smb2.tree`** (e.g. `\\172.16.20.8\profiles`). The files and
folders the client then opens with *Create* requests live in a **different** field,
**`smb2.filename`** (e.g. `dmccoy\backup`, `dmccoy\backup\startup.bat`). The common mistake is to
read a folder path out of `smb2.filename` and call it the share — but that path is folders *inside*
the share, not the share name. Name both: the share is the access boundary, the path is the specific
data touched.

**Carving files — and why it can fail.** `tshark --export-objects <proto>,<dir>` reassembles a
transferred file out of the packets (`smb` for SMB/SMB2 — there is no `smb2` token — `http` for web).
It only works with **full-packet capture**: if the capture used a short snapshot length (snaplen),
only the headers were saved and the payload is gone, so no file can be rebuilt. `capinfos` reports
the packet-size limit.

This lab is CLI-only (`tshark`), so you work it the way a real triage box does. If you'd rather use
the GUI, copy the `.pcapng` to your host and open it in Wireshark — the fields are identical.

## Tasks

Start the lab with `./lab up tshark-tcp-smb`, open a shell with `./lab shell tshark-tcp-smb`.

The capture is at `/opt/captures/slow-smb.pcapng`: a workstation (`172.16.20.15`) reads a file off a
file server, and the transfer is slow. Write each finding into `/root/answers.txt`
(one `KEY=value` per line; the file is already there with the keys).

1. **Drive tshark.** Set `READ_FLAG` to the flag that reads a saved capture, `FILTER_FLAG` to the
   flag that applies a display filter, and `FIELDS_MODE` to the `-T` output mode that prints chosen
   fields (used with `-e`).
2. **Diagnose the slowness.** Set `LOSS_FIELD` to the `tcp.analysis.*` field that surfaces the
   duplicate-ACK storm, and `CONDITION` to the one-word network problem it points to.
3. **Identify the SMB2 transfer.** Set `PROTOCOL` to the application-layer protocol carrying the
   read, `SERVER_IP` to the file server, `SHARE` to the share the client mounts (read `smb2.tree`),
   and `FOLDER_PATH` to the folder path opened inside the share (read `smb2.filename`, without the
   file name).
4. **Carve the file.** Set `EXPORT_FLAG` to the tshark flag that exports transferred objects. Run it
   against the capture and confirm it recovers nothing — then look at `capinfos` to see why.

Check your work from the host: `./lab check tshark-tcp-smb`

<details>
<summary>Hints</summary>

- Count a TCP symptom: `tshark -r /opt/captures/slow-smb.pcapng -Y 'tcp.analysis.duplicate_ack' | wc -l`.
- List the SMB2 share and paths: `tshark -r … -Y smb2 -T fields -e smb2.tree -e smb2.filename | sort -u`.
- `smb2.tree` is `\\server\share`; the share is the part after the last `\`. `smb2.filename` is the
  path *inside* the share.
- Try to carve: `tshark -r … --export-objects smb,/tmp/out` then `ls /tmp/out`.
- `capinfos /opt/captures/slow-smb.pcapng` — look at the packet-size limit.

</details>

## My notes

<!-- Screenshots: ./lab shot tshark-tcp-smb ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `wireshark-fundamentals` — the GUI/panes and follow-stream companion to this CLI lab.
- `tcp-connections`, `dns-resolution` — other network labs.
