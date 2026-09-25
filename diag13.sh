#!/bin/bash
# 检查 fpk 工件内部的 cmd/main 语义（注意 fpk 内层是 app.tgz）
FPK=/tmp/fancontrol-smoke/dist/fan-control_0.1.0.fpk
echo "=== fpk 顶层 ==="
tar -tzf $FPK
echo "=== 解开内层 app.tgz 看 cmd/main? 不，cmd 在顶层 ==="
tar -xzOf $FPK cmd/main 2>&1 | grep -nE "return 3|exit 3"
echo "=== 若上面空，列 cmd/ 下的成员名 ==="
tar -tzf $FPK | grep cmd
