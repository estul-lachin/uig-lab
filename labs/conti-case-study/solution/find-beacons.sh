#!/usr/bin/env bash
# Flag regular call-backs in Sysmon network events (JSON Lines on stdin).
# A (Computer, Image, DestinationIp) series is a beacon when it has at least 8 connections, its median
# gap is 30 s to 1 h, and every gap is within 25 % of that median. Prints Computer,Image,DestinationIp.
jq -rs '
  map(select(.Channel == "Sysmon" and .EventID == 3))
  | group_by([.Computer, .Image, .DestinationIp])[]
  | (map(.UtcTime | strptime("%Y-%m-%d %H:%M:%S") | mktime) | sort) as $t
  | select(($t | length) >= 8)
  | [range(1; $t | length) as $i | $t[$i] - $t[$i - 1]] as $g
  | ($g | sort | .[(length / 2 | floor)]) as $m
  | select($m >= 30 and $m <= 3600 and all($g[]; . >= $m * 0.75 and . <= $m * 1.25))
  | [.[0].Computer, .[0].Image, .[0].DestinationIp] | join(",")'
