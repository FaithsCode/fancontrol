#!/bin/bash
# 从 trim 可执行文件或 nginx 中提取 fnOS 版本
echo "---nginx 配置/版本---"
/usr/trim/nginx/sbin/nginx -v 2>&1 | head -2
echo "---trim 核心服务的版本串---"
for bin in trimrss trimccd trim_app_center; do
  f=$(find /usr/trim/bin /usr/local/bin -name "$bin" 2>/dev/null | head -1)
  if [ -n "$f" ]; then
    v=$(strings "$f" 2>/dev/null | grep -oE "1\.[0-9]+\.[0-9]+" | head -1)
    echo "$bin: $v"
  fi
done
echo "---全部 trim 开头 dpkg 包名与版本---"
dpkg -l 2>/dev/null | awk '/^ii/ && /trim/ {print $2, $3}' | grep -vE "samba|ldb|talloc|tdb|tevent|avahi|firmware|NetworkManager|libnm" | head -15
echo "---kernel 版本戳（trim 内核常带 fnOS 版本）---"
uname -v
