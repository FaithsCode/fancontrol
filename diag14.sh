#!/bin/bash
# 找出正在运行的 daemon 用的是哪份代码
PID=$(cat /var/apps/fan-control/var/app.pid 2>/dev/null)
echo "daemon pid: $PID"
if [ -n "$PID" ]; then
  echo "--- cwd ---"
  ls -l /proc/$PID/cwd 2>/dev/null
  echo "--- 打开的脚本 ---"
  ls -l /proc/$PID/cwd/*.py 2>/dev/null | head -6
fi
echo "--- var/src 是否有新 web/app.py（标准库版应含 ThreadingHTTPServer）---"
grep -l "ThreadingHTTPServer" /var/apps/fan-control/var/src/web/app.py 2>/dev/null && echo "var/src = NEW stdlib version" || echo "var/src = OLD flask version or missing"
grep -l "ThreadingHTTPServer" /var/apps/fan-control/target/src/web/app.py 2>/dev/null && echo "target/src = NEW stdlib version" || echo "target/src = OLD flask version"
