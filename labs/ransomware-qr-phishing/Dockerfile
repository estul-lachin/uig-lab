# Stage 1: generate the case's logs (fixed seed). Pinned, multi-arch tags.
FROM python:3.12-slim AS gen
COPY gen/gen_logs.py /gen_logs.py
RUN mkdir /out && python3 /gen_logs.py

# Stage 2: the analyst's workstation.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*
COPY --from=gen /out/ /root/case/logs/
RUN echo 'echo "Lab ransomware-qr-phishing: the logs are in /root/case/logs; tasks in labs/ransomware-qr-phishing/README.md."' >> /root/.bashrc
WORKDIR /root/case
CMD ["sleep", "infinity"]
