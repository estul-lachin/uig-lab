# A Wazuh manager on web-server-01 itself. It reads the shop's nginx access log and sshd log, and
# watches the systemd units and /usr/local/sbin with FIM. Once per container, after the baseline
# scan, a small service plays the morning (config/feed.sh). Filebeat is removed: no indexer here.
FROM wazuh/wazuh-manager:4.14.9
RUN dnf install -y jq diffutils && dnf clean all \
 && rm -rf /etc/services.d/filebeat \
 && mkdir -p /var/log/lab /opt/lab /etc/services.d/lab-feed /wazuh-config-mount/etc \
 && touch /var/log/lab/nginx-access.log /var/log/lab/secure.log
COPY config/baseline/ /
COPY config/wazuh.xml /opt/lab/wazuh.xml
COPY config/timeline.events /opt/lab/timeline.events
COPY config/feed.sh /etc/services.d/lab-feed/run
RUN sed -e '/<directories>\/etc,\/usr\/bin,\/usr\/sbin<\/directories>/r /opt/lab/wazuh.xml' \
        -e '/<directories>\/etc,\/usr\/bin,\/usr\/sbin<\/directories>/d' \
        -e '/<directories>\/bin,\/sbin,\/boot<\/directories>/d' \
        -e '0,/<\/ossec_config>/s##  <localfile>\n    <log_format>apache</log_format>\n    <location>/var/log/lab/nginx-access.log</location>\n  </localfile>\n  <localfile>\n    <log_format>syslog</log_format>\n    <location>/var/log/lab/secure.log</location>\n  </localfile>\n</ossec_config>#' \
      /var/ossec/etc/ossec.conf > /wazuh-config-mount/etc/ossec.conf \
 && grep -q 'realtime="yes"' /wazuh-config-mount/etc/ossec.conf \
 && grep -q 'nginx-access.log' /wazuh-config-mount/etc/ossec.conf \
 && chmod 755 /etc/services.d/lab-feed/run /usr/local/sbin/rotate-logs \
 && echo 'echo "Lab wazuh-intrusion-capstone: alerts are in /var/ossec/logs/alerts/alerts.json, raw logs in /var/log/lab/ (the morning is over when /var/lib/lab-feed-done exists). Answers go in /root/answers.txt."' >> /root/.bashrc
