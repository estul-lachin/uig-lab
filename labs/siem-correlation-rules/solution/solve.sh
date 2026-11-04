# Reference solution for siem-correlation-rules.
set -eu
umask 022
O=/var/ossec

printf '%s\n' root: administrator: svc_backup: > $O/etc/lists/privileged-accounts
chown wazuh:wazuh $O/etc/lists/privileged-accounts
grep -q '<list>etc/lists/privileged-accounts</list>' $O/etc/ossec.conf \
  || sed -i '0,/<list>etc\/lists\/audit-keys<\/list>/s##&\n    <list>etc/lists/privileged-accounts</list>#' $O/etc/ossec.conf

cat > $O/etc/rules/local_rules.xml <<'XML'
<!-- Lab rules: QRadar's building block -> rule -> offense, as Wazuh rules -->
<group name="local,lab,">

  <!-- Building block: matters only in combination, so level 0 (no alert of its own) -->
  <rule id="100100" level="0">
    <if_sid>5715</if_sid>
    <list field="user" lookup="match_key">etc/lists/privileged-accounts</list>
    <description>BB: SSH logon to a privileged account</description>
  </rule>

  <!-- Threshold: 6 wrong passwords from one address within 5 minutes -->
  <rule id="100110" level="10" frequency="6" timeframe="300">
    <if_matched_sid>5760</if_matched_sid>
    <same_srcip />
    <description>Password guessing: 6 failed SSH logons from $(srcip) in 5 minutes</description>
    <mitre><id>T1110.001</id></mitre>
  </rule>

  <!-- Correlation: the building block, after the threshold rule, from the same address -->
  <rule id="100120" level="14" frequency="2" timeframe="600">
    <if_sid>100100</if_sid>
    <if_matched_sid>100110</if_matched_sid>
    <same_srcip />
    <description>Privileged SSH logon from $(srcip) right after password guessing</description>
    <mitre><id>T1078</id></mitre>
  </rule>

</group>
XML
chown wazuh:wazuh $O/etc/rules/local_rules.xml
$O/bin/wazuh-analysisd -t
$O/bin/wazuh-control restart >/dev/null
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done

printf '%s\n' "BUILDING_BLOCK=Building Block" "RULE=Rule" "OFFENSE=Offense" "ORDERED_BY=magnitude" "RULE_TOOL=Rule Wizard" > /root/answers.txt
