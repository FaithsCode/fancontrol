#!/bin/bash
# diag18: 直接验证 0.1.2 fpk 内层的 UI 版本
FPK=/tmp/fancontrol-smoke/dist/fan-control_0.1.2.fpk
ls -la $FPK 2>&1
rm -rf /tmp/fc-012 && mkdir -p /tmp/fc-012
tar -xzf $FPK -C /tmp/fc-012 && echo "extracted"
echo "--- 内层 app.tgz 里 index.html 的 userEditing 出现次数 ---"
rm -rf /tmp/fc-012-app && mkdir -p /tmp/fc-012-app
tar -xzf /tmp/fc-012/app.tgz -C /tmp/fc-012-app
grep -c "userEditing" /tmp/fc-012-app/src/web/templates/index.html 2>&1
echo "--- 顶层 cmd/main 语义 ---"
grep -nE "return 3|exit 3" /tmp/fc-012/cmd/main
echo "--- 已安装的 target/index.html 修改时间 vs var/src ---"
ls -la /var/apps/fan-control/target/src/web/templates/index.html
ls -la /var/apps/fan-control/var/src/web/templates/index.html 2>/dev/null
