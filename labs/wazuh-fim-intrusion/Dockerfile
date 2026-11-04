# A Wazuh manager on web-server-01 itself, with syscheck (FIM) watching a few directories in real time.
# Once per container, after the baseline scan, a small service plays the intrusion (config/intrusion.sh).
# Filebeat is removed: there is no indexer in this lab.
FROM wazuh/wazuh-manager:4.14.9
RUN dnf install -y jq diffutils && dnf clean all \
 && rm -rf /etc/services.d/filebeat \
 && mkdir -p /opt/lab /etc/services.d/lab-intrusion /wazuh-config-mount/etc
COPY config/baseline/ /
COPY config/intrusion.sh /opt/lab/intrusion.sh
COPY config/syscheck.xml /opt/lab/syscheck.xml
# Replace the default directory list with the lab's (and stop ignoring *.log: wiped logs must alert).
RUN sed -e '/<directories>\/etc,\/usr\/bin,\/usr\/sbin<\/directories>/r /opt/lab/syscheck.xml' \
        -e '/<directories>\/etc,\/usr\/bin,\/usr\/sbin<\/directories>/d' \
        -e '/<directories>\/bin,\/sbin,\/boot<\/directories>/d' \
        -e '/<ignore type="sregex">.log\$|.swp\$<\/ignore>/d' \
      /var/ossec/etc/ossec.conf > /wazuh-config-mount/etc/ossec.conf \
 && grep -q 'realtime="yes"' /wazuh-config-mount/etc/ossec.conf \
 && ! grep -q '<directories>/etc,' /wazuh-config-mount/etc/ossec.conf \
 && mv /opt/lab/intrusion.sh /etc/services.d/lab-intrusion/run \
 && chmod 755 /etc/services.d/lab-intrusion/run /usr/local/bin/backup-web.sh \
 && chmod 440 /etc/sudoers.d/webadmins \
 && echo 'echo "Lab wazuh-fim-intrusion: alerts are in /var/ossec/logs/alerts/alerts.json (the intrusion is over when /var/lib/lab-intrusion-done exists). Answers go in /root/answers.txt."' >> /root/.bashrc
