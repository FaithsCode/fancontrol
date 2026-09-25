#!/bin/bash
# diag12: 重装后诊断
echo "=== 1. 已装 cmd/main 的 status 语义 ==="
grep -nE "return 3|exit 3" /var/apps/fan-control/cmd/main
echo ""
echo "=== 2. var 目录内容 ==="
ls -la /var/apps/fan-control/var/ 2>&1 | head -10
echo "=== 3. info.log ==="
tail -30 /var/apps/fan-control/var/info.log 2>&1
echo ""
echo "=== 4. daemon 与端口 ==="
ps aux | grep daemon.py | grep -v grep || echo "no daemon"
ss -tln | grep 8190 || echo "8190 not listening"
echo ""
echo "=== 5. target/src（部署源）==="
ls /var/apps/fan-control/target/src/ 2>&1 | head -8
echo ""
echo "=== 6. 手动拉起（若 daemon 不在）==="
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start; echo "main start exit: $?"
sleep 4
ps aux | grep daemon.py | grep -v grep || echo "no daemon after manual start"
ss -tln | grep 8190 || echo "8190 not listening after manual start"
tail -15 /var/apps/fan-control/var/info.log 2>&1
curl -s --max-time 5 http://127.0.0.1:8190/api/status | head -c 200
