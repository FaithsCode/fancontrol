#!/bin/bash
# diag27: NCT6687 可写驱动方案探测
K=$(uname -r)
echo "=== 1. 内核里有哪些 nct 相关模块 ==="
find /lib/modules/$K/kernel/drivers/hwmon -name "*.ko*" 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -iE "nct|6687" || echo "(none)"
echo "=== 2. modinfo nct6687 / nct6683 ==="
modinfo nct6687 2>&1 | head -3
echo "---"
modinfo nct6683 2>&1 | head -3
echo "=== 3. 内核头文件（决定能否编译 out-of-tree 驱动）==="
ls /usr/src 2>/dev/null || echo "/usr/src 不存在"
ls /lib/modules/$K/build 2>/dev/null | head -3 || echo "无 build 链接（无 headers）"
echo "=== 4. nct6775 模块参数（有无写使能开关）==="
ls /sys/module/nct6775_core/parameters/ 2>/dev/null || echo "(no params)"
echo "=== 5. dpkg 里有没有 fnOS 的 linux-headers 包 ==="
dpkg -l 2>/dev/null | grep -iE "linux-headers" | head -3 || echo "(未安装 headers)"
