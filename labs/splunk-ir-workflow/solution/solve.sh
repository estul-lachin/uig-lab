# Reference solution for splunk-ir-workflow: the answers from SPL, the report over REST.
set -eu
umask 022
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
WIN="index=main sourcetype=wineventlog:json"
FW="index=main sourcetype=fw:traffic"
spl() { curl -sk -u $AUTH --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
for _ in $(seq 1 60); do [ "$(spl '| tstats count where index=main')" = 904 ] && break; sleep 5; done

row=$(spl "search $WIN EventID=4624 TargetUserName=it_admin Computer=DC-01* NOT IpAddress=\"-\" NOT WorkstationName=DC-* | stats count by IpAddress WorkstationName LogonType")
ip=$(echo "$row" | cut -d, -f1); ws=$(echo "$row" | cut -d, -f2)
phish=$(spl "search $WIN EventID=4688 Computer=$ws* NewProcessName=*WINWORD.EXE | sort _time | head 1 | rex field=CommandLine \"(?<f>[^\\\\\\\\\\\"]+\\.docm)\" | table f")
{
  echo "SUSPICIOUS_SRC=$ip"
  echo "SUSPICIOUS_LOGONS=$(echo "$row" | cut -d, -f4)"
  echo "LOGON_TYPE=$(echo "$row" | cut -d, -f3)"
  echo "SRC_WORKSTATION=$ws"
  echo "IP_SOURCETYPES=$(spl "search index=* \"$ip\" | stats dc(sourcetype)")"
  echo "HOST_ONLY_EVENTS=$(spl "search index=main \"$ws\" NOT \"$ip\" | stats count")"
  echo "C2_IP=$(spl "search $FW src_ip=$ip | stats count avg(bytes_out) AS b by dest_ip | where b<1000 | sort - count | head 1 | table dest_ip")"
  echo "PATIENT_ZERO_USER=$(spl "search $WIN EventID=4624 LogonType=2 Computer=$ws* | head 1 | table TargetUserName")"
  echo "PHISH_FILE=$phish"
  echo "FIRST_OBSERVED=$(spl "search $WIN EventID=4688 Computer=$ws* NewProcessName=*WINWORD.EXE | sort _time | head 1 | eval t=strftime(_time, \"%H:%M:%S\") | table t")"
  echo "BRUTE_FAILS=$(spl "search $WIN EventID=4625 TargetUserName=it_admin IpAddress=$ip | stats count")"
  echo "LATERAL_HOST=$(spl "search $WIN EventID=4624 TargetUserName=it_admin IpAddress=$ip NOT Computer=DC-01* | rex field=Computer \"^(?<h>[^.]+)\" | stats count by h | table h")"
  echo "STAGED_ARCHIVE=$(spl "search $WIN EventID=4688 Computer=$ws* NewProcessName=*7z.exe | rex field=CommandLine \"(?<a>C:\\\\\\\\\\S+\\.7z)\" | table a")"
  echo "EXFIL_IP=$(spl "search $FW src_ip=$ip | sort - bytes_out | head 1 | table dest_ip")"
} > /root/answers.txt

NAME=ir_lab
SS=$API/servicesNS/admin/search/saved/searches
curl -sk -u $AUTH -o /dev/null -X DELETE "$SS/$NAME" || true
curl -skf -u $AUTH -o /dev/null "$SS" -d name=$NAME -d dispatch.earliest_time=0 -d dispatch.latest_time=now \
  --data-urlencode "search=index=main (\"$ip\" OR \"$ws\") | eval ir_status=\"contained\", ir_ticket=\"INC-2026-1103\" | table _time sourcetype EventID Computer TargetUserName IpAddress dest_ip CommandLine ir_status ir_ticket | sort 0 _time"
curl -skf -u $AUTH -o /dev/null "$SS/$NAME/acl" -d owner=admin -d sharing=app
