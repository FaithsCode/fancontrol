#!/bin/bash
# diag17: 验证 target/var 的 UI 版本 + 强制刷新 var/src（daemon 运行副本）
echo "--- target/src/web/templates/index.html 版本 ---"
grep -c "userEditing" /var/apps/fan-control/target/src/web/templates/index.html 2>/dev/null && echo "target = NEW" || echo "target = OLD"
echo "--- var/src 版本 ---"
grep -c "userEditing" /var/apps/fan-control/var/src/web/templates/index.html 2>/dev/null && echo "var = NEW" || echo "var = OLD"
echo "--- 刷新 var/src（从 target 复制，daemon 运行副本）---"
pkill -f "python3 daemon.py" 2>/dev/null; sleep 1
rm -rf /var/apps/fan-control/var/src
cp -r /var/apps/fan-control/target/src /var/apps/fan-control/var/src
rm -f /var/apps/fan-control/var/info.log
grep -c "userEditing" /var/apps/fan-control/var/src/web/templates/index.html && echo "var/src refreshed = NEW"
echo "--- 重启 daemon ---"
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start; echo "start exit: $?"
sleep 6
ss -tln | grep 8190 >/dev/null && echo "PORT UP" || echo "PORT DOWN"
curl -s --max-time 5 http://127.0.0.1:8190/ | grep -c "userEditing" && echo "SERVED = NEW UI"
