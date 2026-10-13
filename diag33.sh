#!/bin/bash
# diag33: nct6687 驱动持久化 + 应用恢复
K=$(uname -r)
echo "=== 1. 模块安装到系统目录 ==="
mkdir -p /lib/modules/$K/extra
cp /tmp/nct6687d/nct6687.ko /lib/modules/$K/extra/
depmod -a $K && echo "depmod OK"
echo "=== 2. /etc/modules 处理（nct6775→nct6687）==="
grep -n nct /etc/modules 2>/dev/null && sed -i 's/^nct6775.*/nct6687/' /etc/modules && grep -n nct /etc/modules || echo "nct6687" >> /etc/modules
cat /etc/modules | grep -vE "^#|^$"
echo "=== 3. 重启 daemon（自动重新发现通道）==="
pkill -f "python3 daemon.py" 2>/dev/null; sleep 1
export TRIM_PKGVAR=/var/apps/fan-control/var
bash /var/apps/fan-control/cmd/main start; echo "start exit: $?"
sleep 8
echo "=== 4. API 验证温控闭环恢复 ==="
ss -tln | grep -q 8190 && echo "PORT UP" || echo "PORT DOWN"
curl -s --max-time 8 http://127.0.0.1:8190/api/status > /tmp/st.json
python3 - <<'PY'
import json
d = json.load(open('/tmp/st.json'))
print(f"running={d['running']} sensors={len(d['sensors'])} fans={len(d['fans'])}")
for f in d['fans']:
    cfg = d['config']['fans'].get(f['channel_id'], {})
    sid = cfg.get('sensor_id')
    bound = '已绑定 ' + sid if sid else '安全值'
    print(f"  {f['channel_id']} [{bound}] pwm={f['current_pwm']} rpm={f['current_rpm']}")
PY
