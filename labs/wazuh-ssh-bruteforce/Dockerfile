# A Wazuh manager on its own, watching bastion-01's auth log, which a small service fills once
# per container start (config/feed.sh). Filebeat is removed: there is no indexer in this lab.
FROM wazuh/wazuh-manager:4.14.9
RUN dnf install -y jq && dnf clean all \
 && rm -rf /etc/services.d/filebeat \
 && mkdir -p /var/log/lab /opt/lab /etc/services.d/lab-feed /wazuh-config-mount/etc \
 && touch /var/log/lab/bastion-01.log \
 && sed '0,/<\/ossec_config>/s##  <localfile>\n    <log_format>syslog</log_format>\n    <location>/var/log/lab/bastion-01.log</location>\n  </localfile>\n</ossec_config>#' \
      /var/ossec/etc/ossec.conf > /wazuh-config-mount/etc/ossec.conf
COPY config/bastion-01.events /opt/lab/bastion-01.events
COPY config/feed.sh /etc/services.d/lab-feed/run
RUN chmod 755 /etc/services.d/lab-feed/run \
 && echo 'echo "Lab wazuh-ssh-bruteforce: alerts are in /var/ossec/logs/alerts/alerts.json (feed done when /var/lib/lab-feed-done exists). Answers go in /root/answers.txt."' >> /root/.bashrc
