#!/bin/bash
# 验证 NAS 上 fpk 包内容 + fnOS 版本
FPK=/tmp/fancontrol-smoke/dist/fan-control_0.1.0.fpk
echo "---包存在性---"
ls -la $FPK 2>&1
echo "---包内文件列表---"
tar -tzf $FPK 2>&1 | sort | head -40
echo "---包内 manifest---"
tar -xzOf $FPK ./manifest 2>/dev/null || tar -xzOf $FPK manifest 2>/dev/null
echo "---包内 config/privilege---"
tar -xzOf $FPK ./config/privilege 2>/dev/null || tar -xzOf $FPK config/privilege 2>/dev/null
echo "---fnOS 版本探测---"
for p in /var/version /usr/trim/version /etc/version /etc/trimnode /var/log/trim_version; do
  [ -r "$p" ] && echo "$p: $(cat $p)"
done
find / -maxdepth 3 -name "*version*" -path "*trim*" 2>/dev/null | head -5
echo "---appcenter-cli 版本---"
appcenter-cli --version 2>&1 | head -2
