# A Wazuh manager on its own. Its own rootcheck scan is off; instead a small service hands analysisd
# the rootcheck results of seven fleet hosts, once per container start (config/feed.sh), the same way
# their agents' messages would arrive. Filebeat is removed: there is no indexer in this lab.
FROM wazuh/wazuh-manager:4.14.9
RUN dnf install -y jq && dnf clean all \
 && rm -rf /etc/services.d/filebeat \
 && mkdir -p /opt/lab /etc/services.d/lab-feed /wazuh-config-mount/etc \
 && sed '/<rootcheck>/,/<\/rootcheck>/s#<disabled>no</disabled>#<disabled>yes</disabled>#' \
      /var/ossec/etc/ossec.conf > /wazuh-config-mount/etc/ossec.conf \
 && grep -A1 '<rootcheck>' /wazuh-config-mount/etc/ossec.conf | grep -q '<disabled>yes'
COPY config/fleet.events /opt/lab/fleet.events
COPY config/inject.py /opt/lab/inject.py
COPY config/feed.sh /etc/services.d/lab-feed/run
RUN chmod 755 /etc/services.d/lab-feed/run \
 && echo 'echo "Lab wazuh-rootcheck-trojans: alerts are in /var/ossec/logs/alerts/alerts.json (feed done when /var/lib/lab-feed-done exists). Answers go in /root/answers.txt."' >> /root/.bashrc
