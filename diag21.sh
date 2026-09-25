#!/bin/bash
# diag21: 查 daemon 实际运行副本与时间戳
echo "--- daemon pid 与 cwd ---"
PID=$(pgrep -f "python3 daemon.py" | head -1)
echo "pid=$PID"
ls -l /proc/$PID/cwd
echo "--- 该 cwd 里的 sensors.py 是新版吗（搜悬空通道关键字）---"
grep -c "悬空通道" /proc/$PID/cwd/sensors.py 2>/dev/null
echo "--- cwd/sensors.py 修改时间 ---"
ls -la /proc/$PID/cwd/sensors.py
echo "--- var/src 与 target/src 的时间戳 ---"
ls -la /var/apps/fan-control/var/src/sensors.py /var/apps/fan-control/target/src/sensors.py
echo "--- var/src/sensors.py 搜关键字 ---"
grep -c "悬空通道" /var/apps/fan-control/var/src/sensors.py 2>/dev/null || echo 0
echo "--- target/src/sensors.py 搜关键字 ---"
grep -c "悬空通道" /var/apps/fan-control/target/src/sensors.py 2>/dev/null || echo 0
