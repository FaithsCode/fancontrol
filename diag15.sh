#!/bin/bash
# diag15: 0.1.1 版 daemon 活着但 8190 不监听——验证 var/src 代码版本与 Web 线程状态
echo "=== 1. var/src/web/app.py 是新版还是旧版 ==="
grep -c "ThreadingHTTPServer" /var/apps/fan-control/var/src/web/app.py 2>/dev/null && echo "NEW stdlib" || echo "OLD flask"
echo "=== 2. daemon 线程列表（找 web 线程）==="
PID=$(pgrep -f "python3 daemon.py" | head -1)
echo "daemon pid: $PID"
ls /proc/$PID/task/ 2>/dev/null | wc -l
cat /proc/$PID/task/*/comm 2>/dev/null | sort | uniq -c
echo "=== 3. daemon 的监听 socket（本进程视角）==="
ss -tlnp 2>/dev/null | grep "$PID" || echo "no socket for this pid"
ss -tln | grep 8190 || echo "8190 not listening at all"
echo "=== 4. FAN_WEB_PORT 环境变量（框架传了什么）==="
tr '\0' '\n' < /proc/$PID/environ 2>/dev/null | grep -E "FAN_|TRIM_" | head -10
