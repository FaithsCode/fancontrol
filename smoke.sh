#!/bin/bash
# fn-fan-control 容器启动脚本
# FAN_SMOKE=1: 用 mock hwmon 跑 daemon，3 个控制周期后自检输出 SMOKE OK/FAILED
# 否则: 前台运行 daemon（生产形态）
set -e

if [ "${FAN_SMOKE:-0}" = "1" ]; then
    export FAN_HWMON_BASE=/mock/hwmon
    python3 /app/src/daemon.py &
    DAEMON_PID=$!
    # 等 3 个控制周期（interval=5s，留 20s 余量）
    sleep 20
    echo "=== SMOKE CHECK ==="
    curl -sf http://127.0.0.1:8190/api/status > /tmp/status.json
    python3 - <<'PY'
import json
d = json.load(open('/tmp/status.json'))
fans = d['fans']
sensors = d['sensors']
print(f"sensors: {len(sensors)}, fans: {len(fans)}")
assert len(fans) >= 1, "no fan channel discovered"
fan = fans[0]
print(f"fan: {fan['channel_id']} pwm={fan['current_pwm']} rpm={fan['current_rpm']}")
assert fan['current_pwm'] is not None, "pwm not written"
mock_pwm = int(open('/mock/hwmon/hwmon0/pwm1').read().strip())
print(f"mock pwm1 file: {mock_pwm}")
assert mock_pwm == fan['current_pwm'], "mock pwm file not updated"
temps = {s['id']: s['value'] for s in sensors if s['value'] is not None}
print(f"temps: {temps}")
assert temps, "no temperature read"
print("SMOKE OK")
PY
    kill $DAEMON_PID 2>/dev/null || true
else
    # 非 smoke 模式：直接前台运行 daemon（生产形态）
    exec python3 /app/src/daemon.py
fi
