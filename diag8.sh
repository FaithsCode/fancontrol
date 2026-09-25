#!/bin/bash
# 诊断 10330 启动失败
echo "---1. daemon 进程---"
ps aux 2>/dev/null | grep -E "daemon\.py" | grep -v grep || echo "no daemon process"
echo "---2. 8190 监听---"
ss -tln 2>/dev/null | grep 8190 || echo "8190 not listening"
echo "---3. flask 状态---"
python3 -c "import flask; print('flask OK')" 2>&1 | head -1
echo "---4. pip 可用性---"
command -v pip3 || echo "no pip3"
echo "---5. 应用 var 目录与 info.log（尝试读）---"
ls -la /var/apps/fan-control/var/ 2>&1 | head -8
tail -30 /var/apps/fan-control/var/info.log 2>&1
echo "---6. 部署的 src---"
ls /var/apps/fan-control/var/src/ 2>&1 | head -8
ls /var/apps/fan-control/target/src/ 2>&1 | head -8
