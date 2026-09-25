#!/bin/bash
# 定位 appcenter 10111 错误的详细日志
echo "---appcenter-cli 帮助---"
appcenter-cli --help 2>&1 | head -20
echo "---日志文件候选---"
ls -la /var/log/ 2>/dev/null | grep -iE "trim|app|center" 
echo "---日志中搜 10111---"
grep -r "10111" /var/log/ 2>/dev/null | tail -5
echo "---日志中搜 appcenter 错误---"
grep -riE "appcenter.*error|error.*appcenter" /var/log/messages /var/log/syslog 2>/dev/null | tail -8
echo "---最近日志尾部---"
tail -30 /var/log/messages 2>/dev/null | grep -iE "app|trim" 
journalctl --no-pager -n 40 2>/dev/null | grep -iE "appcenter|10111" | tail -10
