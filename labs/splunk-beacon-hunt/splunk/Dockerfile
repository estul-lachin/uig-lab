# Stage 1: generate the proxy log and the ASN lookup, package the app. Pinned tags; python:3.12-slim is multi-arch.
FROM python:3.12-slim AS gen
COPY gen_proxy.py /gen_proxy.py
COPY lab_data /app/lab_data
RUN mkdir /out && python3 /gen_proxy.py && cp /out/asn_lookup.csv /app/lab_data/lookups/ \
 && tar -C /app -czf /out/lab_data.tgz lab_data

# Stage 2: Splunk Enterprise. amd64 only (Apple Silicon runs it through Rosetta).
FROM splunk/splunk:10.4.5
COPY --from=gen /out/proxy.log /opt/lab-data/
COPY --from=gen /out/lab_data.tgz /opt/lab-app/lab_data.tgz
USER root
RUN chown -R splunk:splunk /opt/lab-data /opt/lab-app && chmod 644 /opt/lab-data/* /opt/lab-app/lab_data.tgz
USER ansible
