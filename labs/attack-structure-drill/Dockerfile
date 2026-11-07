# A drill on the ATT&CK object model: classify IDs by object type, order the
# Pyramid of Pain, and tell tactic / technique / procedure apart. No services -
# just the reference material and an answers file.
FROM ubuntu:24.04

COPY attack/ /opt/attack/

# The learner fills in their answers here; checks read it. Seeded blank so a
# fresh environment passes nothing.
RUN { \
  echo '# ATT&CK structure drill - read /opt/attack/*.txt and fill these in.'; \
  echo ''; \
  echo '# A. Object type of each ID (tactic/technique/sub-technique/software/group/campaign/mitigation)'; \
  for L in A B C D E F G; do echo "ID_$L="; done; \
  echo ''; \
  echo '# B. Pyramid of Pain: the top (most pain) and bottom (least pain) levels'; \
  echo 'PAIN_MOST='; \
  echo 'PAIN_LEAST='; \
  echo ''; \
  echo '# C. Object-model level of each item (tactic/technique/sub-technique/procedure)'; \
  echo 'LEVEL_1='; \
  echo 'LEVEL_2='; \
  echo 'LEVEL_3='; \
  echo ''; \
  echo '# D. Foundations'; \
  echo '# ACRONYM: what does ATT&CK stand for?'; \
  echo 'ACRONYM='; \
  echo '# MAINTAINER: which organisation curates ATT&CK?'; \
  echo 'MAINTAINER='; \
  echo '# PHILOSOPHY: the two-word idea - defend based on how real adversaries behave'; \
  echo 'PHILOSOPHY='; \
  echo ''; \
  echo '# E. The v18 detection model (see /opt/attack/detection.txt)'; \
  echo 'PLAN='; \
  echo 'IMPLEMENTATION='; \
  echo 'DET_PREFIX='; \
  echo 'AN_PREFIX='; \
  echo 'LOGSOURCE_HOME='; \
  echo 'WIN_SECURITY='; \
  } > /root/answers.txt

RUN { \
  echo 'echo "Lab attack-structure-drill: read /opt/attack/ids.txt, levels.txt, pyramid.txt (cat them)."'; \
  echo 'echo "Fill in /root/answers.txt, then from the host: ./lab check attack-structure-drill"'; \
  } >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
