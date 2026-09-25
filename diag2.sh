#!/bin/bash
# 检查 app center 日志（需要 root 的目录，sudo -n 试探；失败则列出可读部分）
echo "---trim_app_center 目录---"
ls -la /var/log/trim_app_center/ 2>&1 | head -10
echo "---apps 目录---"
ls -la /var/log/apps/ 2>&1 | head -10
echo "---尝试读最近的 appcenter 日志---"
for f in /var/log/trim_app_center/*.log; do
  [ -f "$f" ] || continue
  echo "== $f =="
  tail -25 "$f" 2>/dev/null
done
