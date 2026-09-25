#!/bin/bash
# diag22: 验证打包源头——本地工作区副本 /tmp/fancontrol-smoke/fpk/app/src 与 fpk 内层
echo "--- A. 工作区 fpk/app/src/sensors.py（build.sh 复制的源头）---"
grep -c "悬空通道" /tmp/fancontrol-smoke/fpk/app/src/sensors.py 2>/dev/null || echo 0
ls -la /tmp/fancontrol-smoke/fpk/app/src/sensors.py 2>/dev/null
echo "--- B. fpk 内层 app.tgz 里的 sensors.py ---"
rm -rf /tmp/fc-check && mkdir -p /tmp/fc-check
tar -xzf /tmp/fancontrol-smoke/dist/fan-control_0.1.3.fpk -C /tmp/fc-check
tar -xzf /tmp/fc-check/app.tgz -C /tmp/fc-check/app_x 2>/dev/null || { mkdir -p /tmp/fc-check/app_x; tar -xzf /tmp/fc-check/app.tgz -C /tmp/fc-check/app_x; }
grep -c "悬空通道" /tmp/fc-check/app_x/src/sensors.py 2>/dev/null || echo 0
echo "--- C. 上传的 tar 包里的 sensors.py ---"
cd /tmp/fancontrol-smoke && tar -xzf fancontrol-fpk.tar.gz -O src/sensors.py 2>/dev/null | grep -c "悬空通道" || echo 0
echo "--- D. /tmp/sensors_new.py（预演用的新版）---"
grep -c "悬空通道" /tmp/sensors_new.py 2>/dev/null || echo 0
