# Reference solution for linux-file-editing. The editors are interactive, so this writes the same
# end state with sed and redirection; the vim and nano commands are in comments.
set -euo pipefail
cd /root/work

# 1. nano (nano nano-hello.txt; Ctrl+\ staging -> production, A)
echo "Hello from nano" > nano-hello.txt
sed 's/staging/production/g' app.conf > app.conf.new && cat app.conf.new > app.conf && rm app.conf.new

# 2. vim (i ... Esc :wq;  :%s/203.0.113.50/REDACTED/g)
echo "investigation started" > case-notes.txt
vim -Es -c '%s/203\.0\.113\.50/REDACTED/g' -c 'wq' proxy.log

# 3. cat
printf 'written with cat\n' | cat > cat-made.txt
printf 'appended with cat\n' | cat >> cat-made.txt
cat part1.log part2.log > timeline.log

# 4. echo, printf, tee, >
echo "Hello, World!" > greeting.txt
echo "Another line." >> greeting.txt
printf 'user\tnora\nrole\tanalyst\n' > users.tsv
echo "to both" | tee seen.txt >/dev/null
echo "next line" | tee -a seen.txt >/dev/null
date > date.txt
date >> date.txt
date > date.txt

# 5. Triage note
printf '== processes ==\n' > triage.txt
ps aux | tee -a triage.txt >/dev/null
