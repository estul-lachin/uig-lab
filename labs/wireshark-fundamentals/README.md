# wireshark-fundamentals

## Concepts

Wireshark reads a capture through three linked panes. The **Packet List** shows one summary
line per packet in columns (the Protocol column reads the highest layer). Selecting a line drives
the **Packet Details** pane, which expands that packet into its protocol tree
(Ethernet → IP → TCP → application layer). Clicking a field there highlights the matching bytes in
the **Packet Bytes** pane, which shows the raw data as hex on the left and ASCII on the right —
non-printable bytes appear as dots. That link between a parsed field and its raw bytes is how you
confirm exactly what crossed the wire.

A single packet rarely tells the whole story. **Follow → TCP Stream** reassembles a whole
conversation in one window, client bytes in one colour and server bytes in another. For a cleartext
protocol like TELNET or FTP that lays the login bare — the username and password the client typed.

**Display filters** hide clutter without changing the file: a protocol name (`dns`, `telnet`,
`ftp`, `http`); `frame contains "word"` to find a byte string anywhere in a frame;
`ip.src==` / `ip.dst==` for addresses, combined with `and` / `or`. And you can add **custom
columns** built from any field (for example `http.host`) to surface an indicator at a glance.

This lab's capture is CLI-only, so you drive it with `tshark` instead of the GUI — the reading maps
directly (a display filter is `-Y`, and Follow Stream is `-z follow,tcp,ascii,<n>`). If you'd rather
use the real GUI, copy the `.pcapng` to your host and open it in Wireshark.

## Tasks

Start the lab with `./lab up wireshark-fundamentals`, open a shell with `./lab shell wireshark-fundamentals`.

The capture is at `/opt/intro/lab-capture.pcapng`. It records a workstation (`10.10.10.50`) talking
to a server over several cleartext protocols. Write each finding into `/root/answers.txt`
(one `KEY=value` per line; the file is already there with the keys).

1. **The panes and the cleartext login.** Set `BYTES_PANE` to the pane that shows the data as hex
   and ASCII, `PROTOCOL` to the cleartext remote-login protocol the workstation uses, and
   `SERVER_IP` to the server it logs in to.
2. **Follow the TELNET stream.** Recover the login and set `TELNET_USER` and `TELNET_PASS`
   (exactly as typed).
3. **Follow the FTP stream.** The client logs in anonymously; set `FTP_PASS` to the value it sends
   after `USER anonymous`.
4. **Filters and custom columns.** Set `FILTER_PASSWORD` to the display filter that matches every
   frame containing the word `password`, `HTTP_HOST_FIELD` to the field a custom column would use
   for a plain-HTTP host, and `HTTP_HOST` to the host the HTTP recon targeted.

Check your work from the host: `./lab check wireshark-fundamentals`

<details>
<summary>Hints</summary>

- `tshark -r /opt/intro/lab-capture.pcapng` reads the whole capture; add `-Y '<filter>'` to focus it.
- List the TCP streams, then follow one: `tshark -r … -z follow,tcp,ascii,0 -q` (try stream 0, 1, 2 …).
- FTP commands are fields: `tshark -r … -Y 'ftp.request.command=="PASS"' -T fields -e ftp.request.arg`.
- `tshark -r … -Y 'http.request' -T fields -e http.host` prints the Host of each HTTP request.
- `frame contains "password"` is case-sensitive; one of the login prompts is lowercase.

</details>

## My notes

<!-- Screenshots: ./lab shot wireshark-fundamentals ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `dns-resolution`, `tcp-connections` — other network labs.
