#!/bin/bash
# diag23: 从 /tmp/fancontrol-smoke/fpk/app/src（已验证的新版）强刷机器两份副本 + 重启
echo "--- 0. 源头确认 ---"
grep -c "悬空通道" /tmp/fancontrol-smoke/fpk/app/src/sensors.py
echo "--- 1. 停 daemon 与框架进程 ---"
pkill -f "python3 daemon.py" 2>/dev/null; sleep 1
echo "--- 2. 强刷 target/src 与 var/src ---"
rm -rf /var/apps/fan-control/target/src /var/apps/fan-control/var/src
cp -r /tmp/fancontrol-smoke/fpk/app/src /var/apps/fan-control/target/src
cp -r /tmp/fancontrol-smoke/fpk/app/src /var/apps/fan-control/var/src
rm -f /var/apps/fan-control/var/info.log
echo "--- 3. 验证铺上 ---"
grep -c "悬空通道" /var/apps/fan-control/var/src/sensors.py && grep -c "悬空通道" /var/apps/fan-control/target/src/sensors.py
echo "--- 4. cmd/main start 拉起（模拟框架）---"
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start; echo "exit: $?"
sleep 8
echo "--- 5. 终验 ---"
ss -tln | grep -q 8190 && echo "PORT UP" || echo "PORT DOWN"
curl -s --max-time 5 http://127.0.0.1:8190/api/status > /tmp/st.json
python3 - <<'PY'
import json
d = json.load(open('/tmp/st.json'))
nct = [s for s in d['sensors'] if s['id'].startswith('hwmon_hwmon7')]
print(f"sensors={len(d['sensors'])} fans={len(d['fans'])}")
for s in nct:
    print(f"  {s['id']} '{s['label']}' = {s['value']} err={s['error']}")
vals = [s['value'] for s in d['sensors'] if s['value'] is not None]
print(f"max temp = {max(vals)} (should be < 100)")
PY
