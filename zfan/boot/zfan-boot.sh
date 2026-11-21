#!/bin/bash
# Zfan boot takeover: apply the last saved fan/EPP/CPB state before login.
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
STATE=/Users/Shared/zfan-state.plist
LOG=/var/log/zfan-boot.log
PB=/usr/libexec/PlistBuddy
Z=/usr/local/bin/amd-epp
note() { echo "$(date '+%F %T') $*" >> "$LOG"; }

[ -f "$STATE" ] || { note "no state file"; exit 0; }

# wait for the EC kext
n=0
while ! sysctl -n kern.ecfan >/dev/null 2>&1; do
  n=$((n+1)); [ $n -le 60 ] || { note "kern.ecfan not ready"; exit 0; }
  sleep 2
done

get() { $PB -c "Print :$1" "$STATE" 2>/dev/null; }
fan=$(get fanPreset); curve=$(get curveOn)
epp=$(get eppPreset); cpb=$(get cpbOff); batt=$(get batteryAuto)
[ -n "$fan" ] || fan=auto

on_battery=0
pmset -g batt 2>/dev/null | grep -q "Battery Power" && on_battery=1

# EPP + CPB
if [ "$batt" = "true" ] && [ "$on_battery" = "1" ]; then
  "$Z" on >/dev/null 2>&1; "$Z" value 255 >/dev/null 2>&1
  "$Z" cpb off >/dev/null 2>&1
  note "battery auto: EPP 255, CPB off"
else
  case "$epp" in
    0) "$Z" off >/dev/null 2>&1 ;;
    1) "$Z" on >/dev/null 2>&1; "$Z" value 0 >/dev/null 2>&1 ;;
    2) "$Z" on >/dev/null 2>&1; "$Z" value 64 >/dev/null 2>&1 ;;
    3) "$Z" on >/dev/null 2>&1; "$Z" value 128 >/dev/null 2>&1 ;;
    4) "$Z" on >/dev/null 2>&1; "$Z" value 192 >/dev/null 2>&1 ;;
    5) "$Z" on >/dev/null 2>&1; "$Z" value 255 >/dev/null 2>&1 ;;
  esac
  if [ "$cpb" = "true" ]; then "$Z" cpb off >/dev/null 2>&1; else "$Z" cpb on >/dev/null 2>&1; fi
  note "EPP preset $epp, CPB off=$cpb"
fi

# fan
if [ "$curve" = "true" ]; then
  ec=$(sysctl -n kern.ecfan)
  temp=$(echo "$ec" | sed -n 's/.*cpu=\([0-9]*\).*/\1/p'); [ -n "$temp" ] || temp=60
  x0=$(get curve0x); y0=$(get curve0y); x1=$(get curve1x); y1=$(get curve1y)
  x2=$(get curve2x); y2=$(get curve2y); x3=$(get curve3x); y3=$(get curve3y)
  pct=$(awk -v t="$temp" -v x0="${x0:-45}" -v y0="${y0:-40}" -v x1="${x1:-64}" -v y1="${y1:-54}" \
            -v x2="${x2:-75}" -v y2="${y2:-85}" -v x3="${x3:-92}" -v y3="${y3:-100}" 'BEGIN{
    if (t<=x0) p=y0; else if (t>=x3) p=y3;
    else if (t<=x1) p=y0+(y1-y0)*(t-x0)/(x1-x0);
    else if (t<=x2) p=y1+(y2-y1)*(t-x1)/(x2-x1);
    else p=y2+(y3-y2)*(t-x2)/(x3-x2);
    if (p<30) p=30; if (p>90) p=90; printf "%d", p }')
  sysctl kern.ecfan_set="$pct" >/dev/null 2>&1
  note "curve: ${temp}C -> ${pct}%"
else
  case "$fan" in
    auto) sysctl kern.ecfan_set=auto >/dev/null 2>&1 ;;
    *) v=$fan; [ "$v" -gt 90 ] && v=90; sysctl kern.ecfan_set="$v" >/dev/null 2>&1 ;;
  esac
  note "fan preset $fan"
fi
exit 0
