#!/bin/bash
# diag19: fpk 内是新版(4次userEditing)，但 target/var 是旧版 → 安装器解压跳过
# 直接用内层 app.tgz 的内容强刷 target，再让 cmd/main 的部署逻辑刷 var
echo "--- 0. 内层已解出：/tmp/fc-012-app/src ---"
ls /tmp/fc-012-app/src/web/templates/index.html
echo "--- 1. 停 daemon ---"
pkill -f "python3 daemon.py" 2>/dev/null; sleep 1
echo "--- 2. 强刷 target/src（新 UI 源）---"
rm -rf /var/apps/fan-control/target/src
cp -r /tmp/fc-012-app/src /var/apps/fan-control/target/src
grep -c userEditing /var/apps/fan-control/target/src/web/templates/index.html && echo "target = NEW"
echo "--- 3. cmd/main start（自动把 target/src 部署到 var/src 并拉起）---"
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start; echo "exit: $?"
sleep 6
echo "--- 4. 终验 ---"
ss -tln | grep -q 8190 && echo "PORT UP" || echo "PORT DOWN"
N=$(curl -s --max-time 5 http://127.0.0.1:8190/ | grep -c userEditing)
echo "served userEditing count: $N (>=1 即新 UI 上线)"
curl -s --max-time 5 http://127.0.0.1:8190/api/status | head -c 160
