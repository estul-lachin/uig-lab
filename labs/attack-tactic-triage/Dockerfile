# A SOC triage drill: 15 observed behaviours, one per ATT&CK tactic. The learner
# reads each case and names the tactic it serves. No services - just the cases and
# an answers file.
FROM ubuntu:24.04

COPY cases/ /opt/triage/cases/

# The learner records one tactic per case here; checks read it. Seeded blank so a
# fresh environment passes nothing.
RUN { \
  echo '# ATT&CK tactic triage - read each case in /opt/triage/cases/ and name the'; \
  echo '# single ATT&CK TACTIC it serves. Use the tactic name or its TA id, e.g.'; \
  echo '#   CASE_01=Reconnaissance      or      CASE_01=TA0043'; \
  echo '# (This uses the current v19 (2026) matrix: the old "Defense Evasion" tactic'; \
  echo '#  is split into Stealth and Defense Impairment.)'; \
  echo ''; \
  for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15; do echo "CASE_$n="; done; \
  echo ''; \
  echo '# V19_SPLIT: name the TWO tactics that the old Defense Evasion tactic became'; \
  echo 'V19_SPLIT='; \
  } > /root/answers.txt

RUN { \
  echo 'echo "Lab attack-tactic-triage: read the cases in /opt/triage/cases/ (cat them)."'; \
  echo 'echo "Name the ATT&CK tactic for each in /root/answers.txt (CASE_01..CASE_15, V19_SPLIT)."'; \
  echo 'echo "Then from the host: ./lab check attack-tactic-triage"'; \
  } >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
