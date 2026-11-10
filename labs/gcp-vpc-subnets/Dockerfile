# A Cloud Shell look-alike with a stand-in for gcloud (sim/gcloud.py) over a seeded project in a JSON file.
# Always a pinned tag (never latest); ubuntu has arm64 and amd64 builds.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 less \
 && rm -rf /var/lib/apt/lists/*
COPY sim/gcloud.py sim/seed.py /usr/local/lib/gcloud-sim/
RUN printf '#!/bin/sh\nexec python3 -I /usr/local/lib/gcloud-sim/gcloud.py "$@"\n' > /usr/local/bin/gcloud \
 && chmod 755 /usr/local/bin/gcloud \
 && python3 -I /usr/local/lib/gcloud-sim/seed.py
RUN { echo 'PS1='"'"'\u@cloudshell:\w (larchmere-netsec-sbx)\$ '"'"; \
      echo 'echo "Welcome to the gcp-vpc-subnets lab. Your project is larchmere-netsec-sbx; gcloud is a lab stand-in (try gcloud compute networks list)."'; \
      echo 'echo "Tasks: labs/gcp-vpc-subnets/README.md. Answers go in /root/answers.txt. Check from the host with: ./lab check gcp-vpc-subnets"'; \
    } >> /root/.bashrc
WORKDIR /root
CMD ["sleep", "infinity"]
