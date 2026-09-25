#!/bin/bash
# diag11: 确认已安装脚本版本 + 手动拉起观察 daemon 存活情况
echo "=== 1. 已安装 cmd/main 里的 status 语义（return=已修复 / exit=旧版）==="
grep -nE "return 3|exit 3" /var/apps/fan-control/cmd/main
echo ""
echo "=== 2. 手动拉起（TRIM_PKGVAR=var）==="
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start; echo "main start exit: $?"
sleep 4
echo ""
echo "=== 3. daemon 现场 ==="
ps aux | grep daemon.py | grep -v grep || echo "no daemon"
ss -tln | grep 8190 || echo "8190 not listening"
echo "--- info.log ---"
cat /var/apps/fan-control/var/info.log 2>&1 | tail -20
echo ""
echo "=== 4. API ==="
curl -s --max-time 5 http://127.0.0.1:8190/api/status | head -c 200
echo ""
echo "=== 5. 再看 5 秒后进程是否仍活（防闪退）==="
sleep 5
ps aux | grep daemon.py | grep -v grep || echo "daemon died within 9s"
tail -5 /var/apps/fan-control/var/info.log 2>&1
