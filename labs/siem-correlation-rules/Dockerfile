# A Wazuh manager on its own (no indexer or dashboard): the rule engine is all this lab needs.
FROM wazuh/wazuh-manager:4.14.9
RUN echo 'echo "Lab siem-correlation-rules: rules go in /var/ossec/etc/rules/local_rules.xml; test with /var/ossec/bin/wazuh-logtest. Answers go in /root/answers.txt."' >> /root/.bashrc
