#!/bin/bash
# diag34: 定位 M2_1 上的固态盘（找出它的 hwmon 传感器 id）
echo "=== 1. NVMe 盘 → PCI 地址 ==="
for d in /sys/block/nvme*n1; do
  n=$(basename $d)
  bdf=$(readlink -f $d/device 2>/dev/null | grep -oE '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]' | head -1)
  model=$(cat $d/device/model 2>/dev/null)
  echo "  $n  BDF=$bdf  model=$model"
done
echo "=== 2. nvme hwmon → PCI 地址 ==="
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat $h/name 2>/dev/null)" = "nvme" ] || continue
  bdf=$(readlink -f $h/device 2>/dev/null | grep -oE '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]' | head -1)
  echo "  $(basename $h)  BDF=$bdf   temp=$(cat $h/temp1_input 2>/dev/null)"
done
echo "=== 3. 判定 CPU 直连（M2_1）还是 PCH 下挂 ==="
for b in $(ls /sys/bus/pci/devices/ 2>/dev/null); do
  cls=$(cat /sys/bus/pci/devices/$b/class 2>/dev/null)
  [ "${cls:0:4}" = "0108" ] || continue
  parent=$(basename $(dirname $(readlink -f /sys/bus/pci/devices/$b)))
  echo "  NVMe $b 上级桥=$parent"
done
echo "=== 4. PCIe 根端口（00:01.x = CPU 直连）==="
ls -d /sys/bus/pci/devices/0000:00:0[0-9].* 2>/dev/null | head -8
