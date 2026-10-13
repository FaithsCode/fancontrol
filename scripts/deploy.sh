#!/bin/bash
# deploy.sh — fn-fan-control 上机部署（在 NAS 上以 root 执行）
# 用法: sudo bash deploy.sh /tmp/fancontrol-smoke/dist/fan-control_X.Y.Z.fpk /tmp/fancontrol-smoke
# 作用: 安装 fpk → 刷 cmd/main 与源码副本 → 重启 daemon → 自检
# 背景: fnOS 安装器对同 appname 覆盖安装可能跳过解压，故必须显式刷新运行副本
set -u

FPK="${1:?用法: deploy.sh <fpk路径> <构建目录>}"
BUILD="${2:-/tmp/fancontrol-smoke}"
APP=fan-control
APPDIR=/var/apps/$APP

echo "=== 1. 安装 $FPK ==="
appcenter-cli install-fpk "$FPK" 2>&1 | tail -2

echo "=== 2. 停旧进程（先走框架，保持框架状态一致）==="
appcenter-cli stop "$APP" 2>&1 | tail -1
pkill -f "python3 daemon.py" 2>/dev/null && echo "  已停 daemon" || echo "  daemon 未在运行"
sleep 1

echo "=== 3. 刷新运行副本（关键：覆盖安装不改这些）==="
cp "$BUILD/fpk/cmd/main" "$APPDIR/cmd/main" && chmod +x "$APPDIR/cmd/main" && echo "  cmd/main ✓"
rm -rf "$APPDIR/target/src" "$APPDIR/var/src" "$APPDIR/var/info.log" "$APPDIR/var/app.pid"
cp -r "$BUILD/fpk/app/src" "$APPDIR/target/src" && echo "  target/src ✓"
cp -r "$BUILD/fpk/app/src" "$APPDIR/var/src" && echo "  var/src ✓"

echo "=== 4. 启动 ==="
appcenter-cli start "$APP" 2>&1 | tail -2
sleep 8

# 框架状态与进程不一致时会跳过启动 → 直接调生命周期脚本兜底
if ! ss -tln 2>/dev/null | grep -q 8190; then
  echo "  ⚠ 框架启动未生效，回退直接拉起"
  TRIM_PKGVAR="$APPDIR/var" bash "$APPDIR/cmd/main" start
  sleep 6
fi

echo "=== 5. 自检 ==="
ss -tln 2>/dev/null | grep -q 8190 && echo "  端口 8190 ✓" || echo "  ✗ 端口未监听"
PID=$(pgrep -f "python3 daemon.py" | head -1)
[ -n "$PID" ] && echo "  daemon pid=$PID ✓" || echo "  ✗ daemon 未运行"
# 源码版本自检（用构建目录里的标记文件比对）
if [ -f "$BUILD/src/sensors.py" ] && [ -n "$PID" ]; then
  if diff -q "$BUILD/src/sensors.py" "/proc/$PID/cwd/sensors.py" >/dev/null 2>&1; then
    echo "  运行副本与源码一致 ✓"
  else
    echo "  ⚠ 运行副本与源码不一致（可能被安装器覆盖）"
  fi
fi
echo "=== 完成 ==="
