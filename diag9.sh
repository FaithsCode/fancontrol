#!/bin/bash
# 需 sudo：读 daemon 日志与运行现场，定位 10330
echo "---1. daemon 进程---"
ps aux | grep -E "daemon\.py" | grep -v grep || echo "no daemon"
echo "---2. info.log（daemon 的 stdout/stderr 与启动日志）---"
tail -40 /var/apps/fan-control/var/info.log 2>&1
echo "---3. var/src 部署---"
ls /var/apps/fan-control/var/src/ 2>&1 | head -8
echo "---4. 端口---"
ss -tln | grep 8190 || echo "8190 not listening"
echo "---5. 手动前台试跑 daemon（10 秒采样，会真实运行）---"
cd /var/apps/fan-control/var/src 2>/dev/null && timeout 10 python3 daemon.py 2>&1 | head -25
echo "---试跑结束---"
