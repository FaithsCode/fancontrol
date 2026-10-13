#!/bin/bash
# diag31: 编译并加载 nct6687d（互斥：先卸 nct6775）
echo "=== 0. 互斥清场 ==="
lsmod | grep nct6775 && rmmod nct6775_core && echo "nct6775_core 已卸载" || echo "无 nct6775 残留"
lsmod | grep nct || echo "nct 模块全部清空"
echo "=== 1. 解压 + 编译 ==="
cd /tmp && rm -rf nct6687d && tar -xzf nct6687d.tar.gz && cd /tmp/nct6687d && make clean >/dev/null 2>&1; make 2>&1 | tail -3
[ -f nct6687.ko ] && echo "BUILD OK: $(ls -la nct6687.ko | awk '{print $5}') bytes" || { echo "BUILD FAILED"; dmesg | tail -5; exit 1; }
echo "=== 2. 加载 ==="
insmod nct6687.ko && echo "insmod OK"
sleep 3
echo "=== 3. dmesg 识别记录 ==="
dmesg | grep -i nct6687 | tail -4
echo "=== 4. 新 hwmon 视图 ==="
for d in /sys/class/hwmon/hwmon*; do echo "$d: $(cat $d/name 2>/dev/null)"; done
echo "=== 5. pwm 权限位 + 写测试 ==="
for d in /sys/class/hwmon/hwmon*; do
  if [ "$(cat $d/name 2>/dev/null)" = "nct6687" ]; then
    ls -l $d/pwm[0-9] 2>/dev/null | head -4
    OLD=$(cat $d/pwm1 2>/dev/null); echo "pwm1 现值: $OLD, fan1_in: $(cat $d/fan1_input 2>/dev/null)"
    echo 128 > $d/pwm1 2>&1 && echo ">>> WRITE OK: pwm1 $OLD -> $(cat $d/pwm1)" || echo ">>> WRITE DENIED"
    break
  fi
done
