#!/bin/bash
# 诊断 fan-control 启动失败
echo "---1. 应用安装目录---"
ls -la /var/apps/fan-control/ 2>&1 | head -15
echo "---2. target 目录---"
ls -la /var/apps/fan-control/target/ 2>&1 | head -15
echo "---3. 数据目录约定---"
ls -d /vol*/@app* 2>/dev/null
ls -la /vol*/@appdata/fan-control/ 2>/dev/null | head -10
ls -la /vol*/@apphome/fan-control/ 2>/dev/null | head -10
echo "---4. 应用 info.log 内容---"
for f in /vol*/@app*/fan-control/info.log /var/apps/fan-control/var/info.log; do
  [ -r "$f" ] && { echo "== $f =="; tail -20 "$f"; }
done
echo "---5. flask 是否可用---"
python3 -c "import flask; print('flask OK', flask.__version__)" 2>&1 | head -2
echo "---6. 根文件系统是否只读 / vol2 是否存在---"
mount | grep -E " / | /vol" | head -5
ls -d /vol2 2>/dev/null || echo "/vol2 NOT EXIST"
echo "---7. 端口 8190 监听状态---"
ss -tlnp 2>/dev/null | grep 8190 || echo "8190 not listening"
