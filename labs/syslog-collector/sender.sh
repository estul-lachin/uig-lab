#!/bin/bash
# One script for every simulated device; ROLE picks what it sends. Every 2 seconds, forever.
C=collector
i=0
while :; do
  i=$(( i + 1 ))
  case "$ROLE" in
    firewall)
      n=$(( RANDOM % 200 + 2 ))
      logger --server $C --port 514 --udp --rfc3164 -t kernel \
        "FW ALLOW IN=eth0 SRC=10.20.4.$n DST=10.20.0.5 PROTO=TCP SPT=$(( 40000 + i % 2000 )) DPT=443"
      # a port scan from outside, walking through the ports
      logger --server $C --port 514 --udp --rfc3164 -t kernel \
        "FW DROP IN=eth0 SRC=203.0.113.50 DST=10.20.0.5 PROTO=TCP SPT=51515 DPT=$(( i % 1024 + 1 ))"
      [ $(( i % 5 )) = 0 ] && logger --server $C --port 514 --udp --rfc3164 -t kernel \
        "FW DROP IN=eth0 SRC=198.51.100.$(( RANDOM % 50 + 1 )) DST=10.20.0.5 PROTO=UDP SPT=53 DPT=$(( RANDOM % 60000 + 1024 ))"
      ;;
    web)
      # nginx forwards over TCP
      logger --server $C --port 514 --tcp --rfc3164 -t nginx \
        "192.0.2.$(( RANDOM % 200 + 1 )) - - [$(date -u +%d/%b/%Y:%H:%M:%S) +0000] \"GET /shop/item/$(( i % 90 )) HTTP/1.1\" 200 $(( RANDOM % 9000 + 300 ))"
      ;;
    windows)
      logger --server $C --port 514 --udp --rfc3164 -t MSWinEventLog \
        "EventID=$([ $(( i % 4 )) = 0 ] && echo 4625 || echo 4624) Account=user$(( i % 7 )) Workstation=WS-$(( i % 12 )) LogonType=3"
      ;;
    unknown)
      # a camera nobody registered, sending its own format
      logger --server $C --port 514 --udp --rfc3164 -t cam \
        "cam-7 ?? st=0x$(printf %x $(( RANDOM ))) ||| motion=$(( RANDOM % 2 ))"
      ;;
  esac
  sleep 2
done
