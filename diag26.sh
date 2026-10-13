#!/bin/bash
# diag26: 新主板芯片鉴定 + pwm 权限位 + 模块状态
echo "=== 1. 各 hwmon 芯片名 ==="
for d in /sys/class/hwmon/hwmon*; do
  echo "  $(basename $d): $(cat $d/name 2>/dev/null)"
done
echo "=== 2. hwmon6 pwm 文件权限位 ==="
ls -l /sys/class/hwmon/hwmon6/ 2>/dev/null | grep -E 'pwm[0-9]$|pwm[0-9]_enable' | head -10
echo "=== 3. 已加载的风扇驱动模块 ==="
lsmod | grep -E 'nct6775|it87|asus_ec' || echo "(none)"
echo "=== 4. root 手动写测试 pwm1（只读测试，立刻还原）==="
OLD=$(cat /sys/class/hwmon/hwmon6/pwm1 2>/dev/null)
echo 128 > /sys/class/hwmon/hwmon6/pwm1 2>&1 && echo "WRITE OK (was $OLD, now $(cat /sys/class/hwmon/hwmon6/pwm1))" || echo "WRITE DENIED"
echo "=== 5. pwm1_enable 状态 ==="
cat /sys/class/hwmon/hwmon6/pwm1_enable 2>/dev/null || echo "(no enable file)"
echo "=== 6. it87 可用性（模块在内核里吗）==="
modinfo it87 2>&1 | head -2
