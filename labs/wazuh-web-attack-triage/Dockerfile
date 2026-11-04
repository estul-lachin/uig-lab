# A Wazuh manager on its own, reading web-server-01's nginx access log, which a small service fills
# once per container start (config/feed.sh). Filebeat is removed: there is no indexer in this lab.
FROM wazuh/wazuh-manager:4.14.9
RUN dnf install -y jq && dnf clean all \
 && rm -rf /etc/services.d/filebeat \
 && mkdir -p /var/log/lab /opt/lab /etc/services.d/lab-feed /wazuh-config-mount/etc \
 && touch /var/log/lab/web-server-01-access.log \
 && sed '0,/<\/ossec_config>/s##  <localfile>\n    <log_format>apache</log_format>\n    <location>/var/log/lab/web-server-01-access.log</location>\n  </localfile>\n</ossec_config>#' \
      /var/ossec/etc/ossec.conf > /wazuh-config-mount/etc/ossec.conf
COPY config/access.events /opt/lab/access.events
COPY config/feed.sh /etc/services.d/lab-feed/run
RUN chmod 755 /etc/services.d/lab-feed/run \
 && echo 'echo "Lab wazuh-web-attack-triage: alerts are in /var/ossec/logs/alerts/alerts.json, the raw log in /var/log/lab/ (feed done when /var/lib/lab-feed-done exists). Answers go in /root/answers.txt."' >> /root/.bashrc
