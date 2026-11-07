# A Navigator coverage-mapping drill: build an ATT&CK Navigator layer JSON for an
# attack chain, then compute the coverage gaps against a provided detection layer.
# jq is here to work with the layer JSON.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends jq ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY nav/ /opt/nav/

RUN { \
  echo '# ATT&CK Navigator & coverage mapping - see /opt/nav/report.txt and'; \
  echo '# /opt/nav/coverage-layer.json, and the README for the layer format.'; \
  echo '#'; \
  echo '# 1. Build your attack-chain layer as  /root/attack-layer.json : a valid'; \
  echo '#    Navigator Enterprise layer that scores all six chain techniques.'; \
  echo '#'; \
  echo '# 2. GAPS: compare your six attack-chain techniques against the coverage'; \
  echo '#    layer and list the technique ids that are NOT covered (the blind spots).'; \
  echo 'GAPS='; \
  echo ''; \
  echo '# 3. Navigator concepts'; \
  echo '# UNIT: Navigator'"'"'s core unit of work (a saved, annotated view of the matrix)'; \
  echo 'UNIT='; \
  echo '# FORMAT: the file format a layer is saved and shared as'; \
  echo 'FORMAT='; \
  echo '# OVERLAY: how you combine two layers to compare them (a ____ , e.g. a+b)'; \
  echo 'OVERLAY='; \
  echo '# ANALYSIS: colour covered green, overlay a threat layer -> you are doing ____ analysis'; \
  echo 'ANALYSIS='; \
  } > /root/answers.txt

RUN { \
  echo 'echo "Lab attack-navigator-coverage: read /opt/nav/report.txt and /opt/nav/coverage-layer.json."'; \
  echo 'echo "Build /root/attack-layer.json (Navigator layer), fill /root/answers.txt, then: ./lab check attack-navigator-coverage"'; \
  } >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
