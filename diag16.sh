#!/bin/bash
# diag16: 强制刷新 target 与 var/src 到 0.1.1 的内容（安装器跳过同版本文件覆盖的补救）
echo "--- 0. 确认 fpk 内是新版 ---"
tar -xzf /tmp/fancontrol-smoke/dist/fan-control_0.1.1.fpk -C /tmp/fc-extract 2>/dev/null || { mkdir -p /tmp/fc-extract && tar -xzf /tmp/fancontrol-smoke/dist/fan-control_0.1.1.fpk -C /tmp/fc-extract; }
grep -c ThreadingHTTPServer /tmp/fc-extract/app.tgz 2>/dev/null
mkdir -p /tmp/fc-app && tar -xzf /tmp/fc-extract/app.tgz -C /tmp/fc-app
grep -c ThreadingHTTPServer /tmp/fc-app/src/web/app.py && echo "fpk 内层 = NEW stdlib"
echo ""
echo "--- 1. 停 daemon（避免文件占用）---"
pkill -f "python3 daemon.py" 2>/dev/null; sleep 1
echo "--- 2. 刷 target/src ---"
rm -rf /var/apps/fan-control/target/src
cp -r /tmp/fc-app/src /var/apps/fan-control/target/src
echo "--- 3. 刷 var/src（daemon 运行副本）---"
rm -rf /var/apps/fan-control/var/src
cp -r /tmp/fc-app/src /var/apps/fan-control/var/src
rm -f /var/apps/fan-control/var/info.log
echo "--- 4. 验证 ---"
grep -c ThreadingHTTPServer /var/apps/fan-control/var/src/web/app.py && echo "var/src = NEW"
echo "--- 5. 重启 daemon（走 cmd/main start，模拟框架）---"
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start; echo "start exit: $?"
sleep 6
echo "--- 6. 现场 ---"
ss -tln | grep 8190 && echo "PORT UP" || echo "PORT STILL DOWN"
curl -s --max-time 5 http://127.0.0.1:8190/api/status | head -c 260
echo ""
tail -8 /var/apps/fan-control/var/info.log 2>&1
