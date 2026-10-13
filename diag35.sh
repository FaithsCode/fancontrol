#!/bin/bash
# diag35: 确认 0.1.9 源码是否真的上机 + daemon 进程年龄
echo "=== 1. 源码副本里有没有 VirtualSensor ==="
echo -n "  上传源 /tmp/fancontrol-smoke/fpk/app/src/sensors.py: "
grep -c "VirtualSensor" /tmp/fancontrol-smoke/fpk/app/src/sensors.py 2>/dev/null || echo 0
echo -n "  运行副本 var/src/sensors.py:                    "
grep -c "VirtualSensor" /var/apps/fan-control/var/src/sensors.py 2>/dev/null || echo 0
echo -n "  target/src/sensors.py:                          "
grep -c "VirtualSensor" /var/apps/fan-control/target/src/sensors.py 2>/dev/null || echo 0
echo "=== 2. daemon 进程（启动时间 / cwd）==="
ps -eo pid,lstart,etime,cmd | grep "python3 daemon.py" | grep -v grep
PID=$(pgrep -f "python3 daemon.py" | head -1)
echo "  cwd: $(readlink -f /proc/$PID/cwd 2>/dev/null)"
echo -n "  运行中副本是否含 VirtualSensor: "
grep -c "VirtualSensor" /proc/$PID/cwd/sensors.py 2>/dev/null || echo 0
echo "=== 3. fpk 内层（0.1.9）==="
rm -rf /tmp/fc019 && mkdir -p /tmp/fc019
tar -xzf /tmp/fancontrol-smoke/dist/fan-control_0.1.9.fpk -C /tmp/fc019 2>/dev/null
mkdir -p /tmp/fc019/app && tar -xzf /tmp/fc019/app.tgz -C /tmp/fc019/app 2>/dev/null
echo -n "  fpk 内层 sensors.py: "
grep -c "VirtualSensor" /tmp/fc019/app/src/sensors.py 2>/dev/null || echo 0
