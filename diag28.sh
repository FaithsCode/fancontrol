#!/bin/bash
# diag28: 用 nct6683 驱动接管 NCT6687（可写验证）
echo "=== 1. 停 daemon（避免切换期间报错风暴）==="
pkill -f "python3 daemon.py" 2>/dev/null; sleep 1
echo "=== 2. 卸载只读视图（nct6775 系）==="
rmmod nct6775 2>/dev/null; rmmod nct6775_core 2>/dev/null
lsmod | grep nct || echo "已全部卸载"
echo "=== 3. 加载 nct6683 ==="
modprobe nct6683 && echo "modprobe OK"
sleep 2
echo "=== 4. dmesg 看是否认出芯片 ==="
dmesg | grep -iE "nct668|6687" | tail -5
echo "=== 5. 新 hwmon 视图与 pwm 权限 ==="
for d in /sys/class/hwmon/hwmon*; do
  n=$(cat $d/name 2>/dev/null)
  [ "$n" = "nct6683" ] && { echo "找到: $d ($n)"; ls -l $d/pwm[0-9] 2>/dev/null | head -4; break; }
done
echo "=== 6. root 写测试 ==="
for d in /sys/class/hwmon/hwmon*; do
  [ "$(cat $d/name 2>/dev/null)" = "nct6683" ] && { echo 200 > $d/pwm1 2>&1 && echo "WRITE OK pwm1=$(cat $d/pwm1)" || echo "WRITE DENIED"; break; }
done
