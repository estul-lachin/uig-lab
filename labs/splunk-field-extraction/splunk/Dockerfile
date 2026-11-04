# Built with ../splunk-search-basics/splunk as the context (the shared shop data) and this folder as the
# extra context "lab" (bastion-01). Pinned tags; python:3.12-slim is multi-arch.
FROM python:3.12-slim AS gen
COPY gen_data.py /gen_data.py
COPY lab_data /app/lab_data
COPY --from=lab gen_bastion.py /gen_bastion.py
COPY --from=lab fx_data /app/fx_data
RUN mkdir /out && python3 /gen_data.py && python3 /gen_bastion.py \
 && tar -C /app -czf /out/lab_data.tgz lab_data && tar -C /app -czf /out/fx_data.tgz fx_data

# Splunk Enterprise. amd64 only (Apple Silicon runs it through Rosetta).
FROM splunk/splunk:10.4.5
COPY --from=gen /out/*.log /out/eve.json /opt/lab-data/
COPY --from=gen /out/lab_data.tgz /out/fx_data.tgz /opt/lab-app/
USER root
RUN chown -R splunk:splunk /opt/lab-data /opt/lab-app && chmod 644 /opt/lab-data/* /opt/lab-app/*.tgz
USER ansible
