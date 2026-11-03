# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# Sample files to practise on.
RUN mkdir -p /root/scripts /root/data/logs \
 && printf 'a\nb\nc\n' > /root/data/logs/web.log \
 && printf 'one line\n' > "/root/data/logs/old backup.log" \
 && printf 'x\ny\n' > /root/data/logs/notes.txt \
 && printf '%s\n' '  indented line' 'path C:\temp\new' '' 'last line without newline' | head -c -1 > /root/data/sample.txt

# Task 4: a baseline of accounts, then two accounts added after it was taken.
RUN cut -d: -f1 /etc/passwd > /root/data/baseline-users.txt \
 && useradd -m -s /bin/bash svc-sync \
 && useradd -M -s /bin/bash -d /var/tmp/.x kthreadd2

RUN echo 'echo "Lab bash-loops: tasks are in labs/bash-loops/README.md. Check from the host with: ./lab check bash-loops"' >> /root/.bashrc

WORKDIR /root/scripts
CMD ["sleep", "infinity"]
