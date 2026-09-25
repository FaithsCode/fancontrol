#!/bin/bash
# diag24: 刷新 + 重启 + 验证 identify 上机（一体）
echo "--- 0. 工作区副本确认 ---"
grep -c "identifyFan" /tmp/fancontrol-smoke/fpk/app/src/web/templates/index.html
echo "--- 1. 停 daemon ---"
pkill -f "python3 daemon.py" 2>/dev/null; sleep 1
echo "--- 2. 强刷两份副本 ---"
rm -rf /var/apps/fan-control/target/src /var/apps/fan-control/var/src /var/apps/fan-control/var/info.log
cp -r /tmp/fancontrol-smoke/fpk/app/src /var/apps/fan-control/target/src
cp -r /tmp/fancontrol-smoke/fpk/app/src /var/apps/fan-control/var/src
echo "--- 3. 拉起 ---"
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start; echo "exit: $?"
sleep 6
echo "--- 4. served 验证 ---"
ss -tln | grep -q 8190 && echo "PORT UP" || echo "PORT DOWN"
N=$(curl -s --max-time 5 http://127.0.0.1:8190/ | grep -c "identifyFan")
echo "served identifyFan count: $N (>=1 即新版)"
