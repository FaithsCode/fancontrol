#!/bin/bash
# apply_plan.sh: 应用风扇绑定方案（修正版：上层进风 / 下层排风分工）
API=http://127.0.0.1:8190
post() {
  curl -s --max-time 8 -X POST "$API/api/fan/$1" -H 'Content-Type: application/json' -d "$2" -o /dev/null -w "  $1 → HTTP %{http_code}\n"
}

echo "=== CPU_FAN1 (pwm1) ← CPU Package；CPU 负载驱动 ==="
post hwmon6_pwm1 '{"display_name":"CPU 风扇 A6x25","mode":"auto","sensor_id":"hwmon_hwmon9/temp1","min_pwm":77,"safety_pwm":204,
"curve":[{"temp":45,"pwm":77},{"temp":60,"pwm":128},{"temp":72,"pwm":191},{"temp":85,"pwm":255}]}'

echo "=== SYS_FAN1/2/6 (pwm3/4/8) ← 主板 System；上层进风，服务主板/CPU/GPU 区 ==="
for ch in hwmon6_pwm3 hwmon6_pwm4 hwmon6_pwm8; do
  post $ch '{"display_name":"上层进风 A8x25","mode":"auto","sensor_id":"hwmon_hwmon6/temp2","min_pwm":77,"safety_pwm":179,
  "curve":[{"temp":38,"pwm":77},{"temp":45,"pwm":115},{"temp":52,"pwm":179},{"temp":60,"pwm":255}]}'
done

echo "=== SYS_FAN4 (pwm6) ← GPU；A3000LP 被动散热 + LSI 3008 吹风（4×B6015）==="
post hwmon6_pwm6 '{"display_name":"GPU+HBA 4×B6015","mode":"auto","sensor_id":"gpu_0","min_pwm":77,"safety_pwm":204,
"curve":[{"temp":40,"pwm":77},{"temp":55,"pwm":128},{"temp":68,"pwm":191},{"temp":78,"pwm":255}]}'

echo "=== SYS_FAN5 (pwm7) ← 硬盘最高温；下层排风 = 硬盘散热主力（2×A12x25）==="
post hwmon6_pwm7 '{"display_name":"下层排风 2×A12x25","mode":"auto","sensor_id":"max_hdd","min_pwm":89,"safety_pwm":204,
"curve":[{"temp":38,"pwm":89},{"temp":43,"pwm":128},{"temp":48,"pwm":191},{"temp":53,"pwm":255}]}'

echo "=== 待定：SYS_FAN3 (pwm5) M.2 3pin / PUMP_FAN1 (pwm2) 未使用 ==="
post hwmon6_pwm5 '{"display_name":"M.2 散热 3pin (SYS_FAN3)","mode":"manual","manual_pwm":128}'
post hwmon6_pwm2 '{"display_name":"未使用 (PUMP_FAN1)","mode":"auto"}'

echo "=== 结果核对 ==="
curl -s --max-time 8 $API/api/status | python3 -c "
import json,sys
d=json.load(sys.stdin)
for f in d['fans']:
    c=d['config']['fans'].get(f['channel_id'],{})
    print('  %-14s %-22s src=%-20s pwm=%-4s rpm=%s' % (f['channel_id'], c.get('display_name','') or f['label'], c.get('sensor_id') or '-', f['current_pwm'], f['current_rpm']))
"
