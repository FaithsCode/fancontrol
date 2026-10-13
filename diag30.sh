#!/bin/bash
# diag30: 主线——编译并加载 out-of-tree nct6687 驱动（MSI NCT6687 可写方案）
set -x
echo "=== 0. 清场：确认没有模块占着芯片 ==="
lsmod | grep -E "nct6775|nct668" || echo "干净"
echo "=== 1. 拉取社区驱动源码 ==="
rm -rf /tmp/nct6687-src
git clone --depth 1 https://github.com/fred78990/nct6687.git /tmp/nct6687-src 2>&1 | tail -1
ls /tmp/nct6687-src/
echo "=== 2. 编译（用当前内核 headers）==="
cd /tmp/nct6687-src && make 2>&1 | tail -5
ls -la nct6687.ko 2>/dev/null || { echo "BUILD FAILED"; exit 1; }
echo "=== 3. 加载驱动 ==="
insmod nct6687.ko && echo "insmod OK"
sleep 3
echo "=== 4. 新视图与权限位 ==="
for d in /sys/class/hwmon/hwmon*; do
  n=$(cat $d/name 2>/dev/null)
  echo "$d: $n"
done
echo "=== 5. 找 nct6687 视图并试写 pwm ==="
for d in /sys/class/hwmon/hwmon*; do
  if [ "$(cat $d/name 2>/dev/null)" = "nct6687" ]; then
    ls -l $d/pwm[0-9] 2>/dev/null | head -3
    OLD=$(cat $d/pwm1 2>/dev/null)
    echo 128 > $d/pwm1 2>&1 && echo "WRITE OK pwm1: $OLD -> $(cat $d/pwm1)" || echo "WRITE DENIED"
    break
  fi
done
echo "=== 6. dmesg 尾部 ==="
dmesg | tail -8
