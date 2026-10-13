#!/bin/bash
# fix_floor.sh: 修正上层进风组最低占空比（pwm8 实测 30% 失速、38% 起转 → 抬到 40%）
API=http://127.0.0.1:8190
for ch in hwmon6_pwm3 hwmon6_pwm4 hwmon6_pwm8; do
  curl -s --max-time 8 -X POST "$API/api/fan/$ch" -H 'Content-Type: application/json' \
    -d '{"min_pwm":102,"curve":[{"temp":38,"pwm":102},{"temp":45,"pwm":128},{"temp":52,"pwm":191},{"temp":60,"pwm":255}]}' \
    -o /dev/null -w "  $ch 最低占空比→40% HTTP %{http_code}\n"
done
sleep 10
echo "=== 复核（三把都应 >0 rpm）==="
curl -s --max-time 8 $API/api/status | python3 -c "
import json,sys
d=json.load(sys.stdin)
for f in d['fans']:
    c=d['config']['fans'].get(f['channel_id'],{})
    if '上层进风' in (c.get('display_name') or ''):
        print('  %-14s pwm=%s (%.0f%%)  rpm=%s' % (f['channel_id'], f['current_pwm'], f['current_pwm']/255*100, f['current_rpm']))
"
