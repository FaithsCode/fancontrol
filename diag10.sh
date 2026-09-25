#!/bin/bash
# diag10: 绕过框架手动拉起 cmd/main，判断 10330 是框架层还是脚本层问题
echo "=== 1. 已安装的 manifest（确认装的是哪版包）==="
grep -E "version|checksum" /var/apps/fan-control/manifest
echo ""
echo "=== 2. cmd/main 是否可执行 ==="
ls -la /var/apps/fan-control/cmd/main
echo ""
echo "=== 3. 手动执行 cmd/main start（TRIM_PKGVAR 指向 var）==="
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start
echo "main start exit: $?"
sleep 3
echo ""
echo "=== 4. 启动后现场 ==="
ps aux | grep daemon.py | grep -v grep || echo "no daemon"
ss -tln | grep 8190 || echo "8190 not listening"
echo "--- info.log ---"
cat /var/apps/fan-control/var/info.log 2>&1
echo ""
echo "=== 5. API 探测 ==="
curl -s --max-time 5 http://127.0.0.1:8190/api/status | head -c 300
echo ""
echo ""
echo "=== 6. appcenter 视角的应用列表 ==="
appcenter-cli list 2>&1 | head -15
