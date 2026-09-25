#!/bin/bash
# fn-fan-control 打包脚本（官方 fnpack 标准结构）
# 结构: manifest + app/(ui + src 源码) + cmd/ + config/ + ICON*.PNG
# 实际打包由 NAS 端官方 fnpack 完成；本脚本用于把源码就位并调用 fnpack。
# 用法: bash scripts/build.sh   （需在含 fnpack 的机器上运行，如 fnNAS）
# 产物: dist/fan-control_0.1.0.fpk

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FPK_SRC="$ROOT/fpk"
OUTPUT_DIR="$ROOT/dist"
APP_NAME="fan-control"
APP_VERSION="0.1.7"

echo "=== 打包 ${APP_NAME} v${APP_VERSION}（官方结构） ==="

# 1. Python 源码复制进 fpk/app/src
echo "[组装 app/]"
mkdir -p "$FPK_SRC/app"
rm -rf "$FPK_SRC/app/src"
cp -r "$ROOT/src" "$FPK_SRC/app/src"
rm -rf "$FPK_SRC/app/src/__pycache__" "$FPK_SRC/app/src/web/__pycache__" 2>/dev/null || true

# 2. 前置检查（fnpack build 校验项）
echo "[前置检查]"
# 恢复生命周期脚本执行位（Windows 打包会丢失）
chmod +x "$FPK_SRC/cmd/"* 2>/dev/null || true
[ -f "$FPK_SRC/manifest" ] && echo "  ✓ manifest" || { echo "  ❌ manifest 缺失"; exit 1; }
[ -f "$FPK_SRC/ICON.PNG" ] && echo "  ✓ ICON.PNG" || { echo "  ❌ ICON.PNG 缺失"; exit 1; }
[ -f "$FPK_SRC/ICON_256.PNG" ] && echo "  ✓ ICON_256.PNG" || { echo "  ❌ ICON_256.PNG 缺失"; exit 1; }
[ -f "$FPK_SRC/cmd/main" ] && echo "  ✓ cmd/main" || { echo "  ❌ cmd/main 缺失"; exit 1; }
[ -f "$FPK_SRC/config/privilege" ] && echo "  ✓ config/privilege" || { echo "  ❌ config/privilege 缺失"; exit 1; }
[ -f "$FPK_SRC/app/ui/config" ] && echo "  ✓ app/ui/config" || { echo "  ❌ app/ui/config 缺失"; exit 1; }

# 3. 调用官方 fnpack 打包（有 fnpack 才能保证格式合法）
if ! command -v fnpack >/dev/null 2>&1; then
    echo "❌ 未找到 fnpack（请在 fnNAS 上运行本脚本: ssh fnnas 'cd <工作区> && bash scripts/build.sh'）"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
cd "$FPK_SRC"
fnpack build -d .
# fnpack 产物路径探测（取最新生成的 fpk）
FPK_FILE=$(ls -t $(find . -name "*.fpk") 2>/dev/null | head -1)
if [ -z "$FPK_FILE" ]; then
    echo "❌ fnpack 未生成 fpk 产物"
    exit 1
fi
cp "$FPK_FILE" "${OUTPUT_DIR}/${APP_NAME}_${APP_VERSION}.fpk"

SIZE=$(du -h "${OUTPUT_DIR}/${APP_NAME}_${APP_VERSION}.fpk" | cut -f1)
echo ""
echo "=== 打包完成 ==="
echo "  产物: ${OUTPUT_DIR}/${APP_NAME}_${APP_VERSION}.fpk ($SIZE)"
echo ""
echo "安装:"
echo "  sudo appcenter-cli install-fpk ${OUTPUT_DIR}/${APP_NAME}_${APP_VERSION}.fpk"
