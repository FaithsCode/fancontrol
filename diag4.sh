#!/bin/bash
# 探测 fnOS 版本（非特权路径）
echo "---os-release---"
cat /etc/os-release 2>/dev/null
echo "---usr-lib-os-release---"
cat /usr/lib/os-release 2>/dev/null
echo "---trim-release 候选---"
for p in /etc/trim-release /etc/version /etc/fnos-release /var/version; do
  [ -r "$p" ] && echo "$p: $(cat $p)"
done
echo "---dpkg 包名猜测---"
dpkg -l 2>/dev/null | grep -iE "trim|fnos" | head -5
