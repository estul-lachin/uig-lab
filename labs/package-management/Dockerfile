# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# Unreachable repositories time out after 5 seconds instead of 30+.
RUN printf 'Acquire::http::Timeout "5";\nAcquire::Retries "0";\n' > /etc/apt/apt.conf.d/99lab-timeout

# Task 6: a third-party repository nobody asked for, with signature checks switched off.
RUN echo 'deb [trusted=yes] http://203.0.113.50/ubuntu noble main' > /etc/apt/sources.list.d/updates-mirror.list

# Task 7: a coreutils program replaced by something else.
RUN printf '#!/bin/sh\n# patched\nexec /usr/bin/readlink /proc/self/fd/0\n' > /usr/bin/tty && chmod 755 /usr/bin/tty

RUN echo 'echo "Lab package-management: tasks are in labs/package-management/README.md. Check from the host with: ./lab check package-management"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
