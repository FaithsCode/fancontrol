#!/bin/bash
# diag20: NCT6798 全部温度通道 + 标签 + 实际读数
for d in /sys/class/hwmon/hwmon*; do
  name=$(cat $d/name 2>/dev/null)
  temps=$(ls $d 2>/dev/null | grep -cE '^temp[0-9]+_input$')
  [ "$temps" -gt 0 ] || continue
  echo "=== $d ($name) ==="
  for t in $d/temp*_input; do
    x=$(basename $t _input)
    label=$(cat $d/${x}_label 2>/dev/null || echo "-")
    val=$(cat $t 2>/dev/null)
    echo "  $x [$label] = $((val/1000)) ℃"
  done
done
