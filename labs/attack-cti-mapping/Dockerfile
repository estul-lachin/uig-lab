# A CTI drill: map a prose intrusion report to ATT&CK technique IDs, and name the
# ecosystem projects. No services - just the material and an answers file.
FROM ubuntu:24.04

COPY cti/ /opt/cti/

RUN { \
  echo '# ATT&CK CTI mapping - read /opt/cti/report.txt and /opt/cti/ecosystem.txt'; \
  echo ''; \
  echo '# A. Map each report behaviour to its ATT&CK technique id (T#### or T####.###)'; \
  for n in 1 2 3 4 5 6 7 8 9 10; do echo "MAP_$n="; done; \
  echo ''; \
  echo '# B. The ecosystem'; \
  echo 'ATOMIC='; \
  echo 'EMULATION='; \
  echo 'DEFENSE='; \
  echo 'PURPLE='; \
  echo 'STIX='; \
  } > /root/answers.txt

RUN { \
  echo 'echo "Lab attack-cti-mapping: read /opt/cti/report.txt and /opt/cti/ecosystem.txt (cat them)."'; \
  echo 'echo "Fill in /root/answers.txt (MAP_1..MAP_10 + the ecosystem), then: ./lab check attack-cti-mapping"'; \
  } >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
