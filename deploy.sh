#!/bin/bash
# 一键部署 RightHere：编译检查 + 强制覆盖安装 + 扩展激活
# 用法：./deploy.sh
# 可选：./deploy.sh --build          自动触发 xcodebuild 再部署
# 可选：./deploy.sh --build --universal  编译 Universal Binary（arm64 + x86_64）

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLED_APP="/Applications/RightHere.app"
BUNDLE_ID="com.LimeBits.RightHere.Extension"
OLD_BUNDLE_IDS=(
    "com.b-vibe.RightHere.Extension"
    "com.b-vibe.RightHere.FinderSync"
)
UNIVERSAL=false
NATIVE_ARCH="$(uname -m)"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

BUILD_SETTINGS=()
XCODEBUILD_FLAGS=()
if [ -n "$DEVELOPMENT_TEAM" ]; then
    BUILD_SETTINGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
    XCODEBUILD_FLAGS+=(-allowProvisioningUpdates)
fi

for arg in "$@"; do
    [ "$arg" = "--universal" ] && UNIVERSAL=true
done

DERIVED_APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/RightHere-*/Build/Products/Debug/RightHere.app 2>/dev/null | head -1)

# ── 可选：自动 build ──────────────────────────────────────────
if [ "$1" = "--build" ]; then
    echo "→ 编译中..."
    if [ "$UNIVERSAL" = true ]; then
        echo "  模式: Universal Binary (arm64 + x86_64)"
        xcodebuild -project "$PROJECT_DIR/RightHere.xcodeproj" \
                   -scheme RightHere \
                   -configuration Debug \
                   "${XCODEBUILD_FLAGS[@]}" \
                   ARCHS="arm64 x86_64" \
                   ONLY_ACTIVE_ARCH=NO \
                   "${BUILD_SETTINGS[@]}" \
                   build 2>&1 | grep -E "error:|warning:|Build succeeded|Build FAILED" | tail -20
    else
        echo "  模式: ${NATIVE_ARCH} (本机)"
        xcodebuild -project "$PROJECT_DIR/RightHere.xcodeproj" \
                   -scheme RightHere \
                   -configuration Debug \
                   "${XCODEBUILD_FLAGS[@]}" \
                   -arch "$NATIVE_ARCH" \
                   "${BUILD_SETTINGS[@]}" \
                   build 2>&1 | grep -E "error:|warning:|Build succeeded|Build FAILED" | tail -20
    fi
    DERIVED_APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/RightHere-*/Build/Products/Debug/RightHere.app 2>/dev/null | head -1)
fi

# ── 检查 build 产物 ───────────────────────────────────────────
if [ -z "$DERIVED_APP" ]; then
    echo "✗ 找不到构建产物，请先在 Xcode 里 Cmd+B 或使用 ./deploy.sh --build"
    exit 1
fi

DERIVED_BIN="$DERIVED_APP/Contents/MacOS/RightHere"
INSTALLED_BIN="$INSTALLED_APP/Contents/MacOS/RightHere"

if [ ! -f "$DERIVED_BIN" ]; then
    echo "✗ DerivedData 中找不到主可执行文件，请先在 Xcode 里 Cmd+B 或使用 ./deploy.sh --build"
    exit 1
fi

DERIVED_HASH=$(md5 -q "$DERIVED_BIN" 2>/dev/null || echo "derived_missing")
INSTALLED_HASH=$(md5 -q "$INSTALLED_BIN" 2>/dev/null || echo "not_installed")

if [ "$DERIVED_HASH" = "$INSTALLED_HASH" ] && [ "$1" != "--force" ] && [ "$2" != "--force" ]; then
    echo "✗ DerivedData 里的 build 与已安装版本完全一致（未重新编译）"
    echo "  请在 Xcode 里 Shift+Cmd+K 清理后再 Cmd+B，或运行 ./deploy.sh --build --force 强制重装"
    exit 1
fi

echo "→ 停止旧进程..."
killall RightHereExtension 2>/dev/null || true
killall RightHere 2>/dev/null || true
sleep 0.5

echo "→ 强制覆盖安装到 /Applications..."
rm -rf "$INSTALLED_APP"
cp -r "$DERIVED_APP" "$INSTALLED_APP"

# 校验：比对文件大小确认复制成功
DERIVED_SIZE=$(stat -f "%z" "$DERIVED_BIN" 2>/dev/null || echo 0)
INSTALLED_SIZE=$(stat -f "%z" "$INSTALLED_BIN" 2>/dev/null || echo 0)
if [ "$INSTALLED_SIZE" -ne "$DERIVED_SIZE" ]; then
    echo "✗ 安装失败，文件大小不匹配（src: $DERIVED_SIZE, dst: $INSTALLED_SIZE）"
    exit 1
fi

echo "→ 启动 app..."
open "$INSTALLED_APP"
sleep 2

echo "→ 启用扩展..."
for old_bundle_id in "${OLD_BUNDLE_IDS[@]}"; do
    pluginkit -e ignore -i "$old_bundle_id" 2>/dev/null || true
done
pluginkit -e use -i "$BUNDLE_ID"
sleep 1

echo "→ 等待 extension 进程启动..."
for i in 1 2 3 4 5; do
    if pgrep -x RightHereExtension > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo "→ 重启 Finder..."
killall Finder
sleep 1

# ── 最终验证 ──────────────────────────────────────────────────
STATUS=$(pluginkit -m -p com.apple.FinderSync 2>&1 | grep "$BUNDLE_ID")
if echo "$STATUS" | grep -q "^+"; then
    INSTALLED_DATE=$(date "+%H:%M:%S")
    echo "✓ 部署成功（时间: $INSTALLED_DATE）"
    echo "  扩展状态: $STATUS"
else
    echo "✗ 扩展未激活: $STATUS"
    exit 1
fi
