#!/bin/bash
# diag29: 恢复传感器视图 + 检查编译工具链
echo "=== 1. 卸掉没用的 nct6683，恢复 nct6775（传感器视图）==="
rmmod nct6683 2>/dev/null
modprobe nct6775 && echo "nct6775 back"
sleep 2
for d in /sys/class/hwmon/hwmon*; do
  n=$(cat $d/name 2>/dev/null)
  [ "$n" = "nct6687" ] && echo "传感器视图恢复: $d"
done
echo "=== 2. 编译工具链 ==="
for t in gcc make git; do
  command -v $t >/dev/null && echo "$t: $($t --version | head -1)" || echo "$t: 缺失"
done
echo "=== 3. 网络连通性（GitHub 直连）==="
timeout 8 curl -sI https://github.com 2>&1 | head -1 || echo "GitHub 不可达"
echo "=== 4. 磁盘空间（/tmp 编译用）==="
df -h /tmp | tail -1
