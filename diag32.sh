#!/bin/bash
# diag32: 突破 EC 自动模式——enable 切手动 + 连写 + 转速观察
D=/sys/class/hwmon/hwmon6
echo "=== 1. enable 文件存在吗 ==="
ls $D/pwm[0-9]_enable 2>/dev/null | head -3 || echo "(无 enable 文件)"
echo "=== 2. 若有 enable：pwm1 切手动(1)再写 ==="
if [ -f $D/pwm1_enable ]; then
  echo "pwm1_enable 现值: $(cat $D/pwm1_enable)"
  echo 1 > $D/pwm1_enable 2>&1 && echo "enable->1 OK" || echo "enable 写入失败"
fi
echo "=== 3. 连写 pwm1=200 三遍 ==="
for i in 1 2 3; do echo 200 > $D/pwm1 2>/dev/null; sleep 0.3; done
sleep 2
echo "pwm1 读回: $(cat $D/pwm1)  fan1_rpm: $(cat $D/fan1_input 2>/dev/null)"
echo "=== 4. 对照组：有风扇的 pwm3 也试（enable->1, 写 240）==="
if [ -f $D/pwm3_enable ]; then echo 1 > $D/pwm3_enable 2>/dev/null; fi
for i in 1 2 3; do echo 240 > $D/pwm3 2>/dev/null; sleep 0.3; done
sleep 3
echo "pwm3 读回: $(cat $D/pwm3)  fan3_rpm: $(cat $D/fan3_input 2>/dev/null)"
echo "=== 5. 再写 pwm3=60（减速方向）==="
for i in 1 2 3; do echo 60 > $D/pwm3 2>/dev/null; sleep 0.3; done
sleep 4
echo "pwm3 读回: $(cat $D/pwm3)  fan3_rpm: $(cat $D/fan3_input 2>/dev/null)"
