#!/bin/bash
# 定位 fnOS 版本号（找 trim 基础包或 appcenter 自身的版本）
echo "---trim-base/appcenter 包---"
dpkg -l 2>/dev/null | grep -iE "trim.*(base|core|center|app)" | head -8
echo "---trim-ccd / trimrss---"
ls /usr/trim/ 2>/dev/null
echo "---appcenter 二进制里 grep 版本串---"
strings /usr/local/bin/appcenter-cli 2>/dev/null | grep -oE "1\.[0-9]+\.[0-9]+" | head -5
echo "---/usr/trim/bin 下的关键文件---"
ls /usr/trim/bin 2>/dev/null | head -20
echo "---trim-bin 包版本---"
dpkg -l 2>/dev/null | awk '{print $2, $3}' | grep -E "^trim" | head -10
