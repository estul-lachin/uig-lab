# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# A couple of files in the working directory, so an unquoted * visibly expands.
RUN mkdir -p /root/scripts && touch /root/scripts/notes.md /root/scripts/todo.txt

RUN echo 'echo "Lab bash-variables-quoting: tasks are in labs/bash-variables-quoting/README.md. Check from the host with: ./lab check bash-variables-quoting"' >> /root/.bashrc

WORKDIR /root/scripts
CMD ["sleep", "infinity"]
