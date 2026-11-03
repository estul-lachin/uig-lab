# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# kai owns the workspace, lee is on kai's crew, zoe is someone else.
RUN groupadd crew \
 && useradd -m -s /bin/bash kai \
 && useradd -m -s /bin/bash -G crew lee \
 && useradd -m -s /bin/bash zoe \
 && chmod 755 /home/kai

# Task 4: a project tree that is far too open, with a subdirectory the crew can't enter.
RUN mkdir -p /home/kai/project/drafts \
 && echo "plan" > /home/kai/project/plan.md \
 && echo "budget" > /home/kai/project/budget.csv \
 && echo "draft 1" > /home/kai/project/drafts/d1.md \
 && chown -R kai:crew /home/kai/project \
 && chmod 0646 /home/kai/project/plan.md /home/kai/project/budget.csv /home/kai/project/drafts/d1.md \
 && chmod 0707 /home/kai/project/drafts \
 && chmod 0757 /home/kai/project

# Task 6: two directories with unusual modes, to reason about.
RUN mkdir -p /srv/listonly /srv/dropbox \
 && echo "visible name, hidden content" > /srv/listonly/report.txt \
 && echo "already here" > /srv/dropbox/existing.txt \
 && chmod 744 /srv/listonly && chmod 644 /srv/listonly/report.txt \
 && chmod 733 /srv/dropbox && chmod 644 /srv/dropbox/existing.txt

RUN echo 'echo "Lab unix-permissions: tasks are in labs/unix-permissions/README.md. Check from the host with: ./lab check unix-permissions"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
