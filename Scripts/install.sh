#!/usr/bin/env bash
# RightHere 安装脚本 — 双击「安装 RightHere.command」运行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="RightHere.app"
APP_SRC="${SCRIPT_DIR}/${APP_NAME}"
APP_DEST="/Applications/${APP_NAME}"
BUNDLE_ID="com.LimeBits.RightHere.Extension"
OLD_BUNDLE_IDS=(
    "com.b-vibe.RightHere.Extension"
    "com.b-vibe.RightHere.FinderSync"
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RightHere 安装程序"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 检查 DMG 里的 app ─────────────────────────────────────────
if [[ ! -d "${APP_SRC}" ]]; then
    echo "✗ 找不到 RightHere.app"
    echo "  请确保「安装 RightHere.command」和「RightHere.app」在同一个 DMG 窗口里。"
    read -p "按回车键退出..." _
    exit 1
fi

# ── 停止旧进程 ────────────────────────────────────────────────
echo "→ 停止旧版本..."
killall RightHereExtension 2>/dev/null || true
killall RightHere 2>/dev/null || true
sleep 0.3

# ── 复制到 /Applications ──────────────────────────────────────
echo "→ 安装到 /Applications..."
rm -rf "${APP_DEST}"
cp -R "${APP_SRC}" "${APP_DEST}"

# ── 清除所有 Gatekeeper 隔离标记（必须在 open 之前）─────────
echo "→ 移除系统隔离标记（需要管理员密码）..."
sudo xattr -cr "${APP_DEST}"

# ── 注册到 LaunchServices ─────────────────────────────────────
echo "→ 刷新应用图标缓存..."
touch "${APP_DEST}"
touch "${APP_DEST}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister \
    -f -R -trusted "${APP_DEST}" 2>/dev/null || true
killall Dock 2>/dev/null || true

# ── 启动 app ──────────────────────────────────────────────────
echo "→ 启动 RightHere..."
open "${APP_DEST}"
sleep 1

# ── 激活 Finder 扩展 ──────────────────────────────────────────
echo "→ 激活 Finder 扩展..."
for old_bundle_id in "${OLD_BUNDLE_IDS[@]}"; do
    pluginkit -e ignore -i "${old_bundle_id}" 2>/dev/null || true
done

STATUS=""
for i in {1..10}; do
    STATUS=$(pluginkit -m -p com.apple.FinderSync -A -D 2>/dev/null | grep "${BUNDLE_ID}" || true)
    if [[ -n "${STATUS}" ]]; then
        break
    fi
    sleep 0.5
done

pluginkit -e use -i "${BUNDLE_ID}" 2>/dev/null || true

for i in {1..8}; do
    STATUS=$(pluginkit -m -p com.apple.FinderSync -A -D 2>/dev/null | grep "${BUNDLE_ID}" || true)
    if echo "${STATUS}" | grep -q "^+"; then
        break
    fi
    sleep 0.5
done

echo "→ 等待扩展进程启动..."
for i in 1 2 3 4 5; do
    if pgrep -x RightHereExtension > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# ── 重启 Finder ───────────────────────────────────────────────
echo "→ 重启 Finder..."
killall Finder 2>/dev/null || true
sleep 1

# ── 验证结果 ──────────────────────────────────────────────────
STATUS=$(pluginkit -m -p com.apple.FinderSync -A -D 2>/dev/null | grep "${BUNDLE_ID}" || true)

echo ""
if echo "${STATUS}" | grep -q "^+"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✓ 安装成功！"
    echo ""
    echo "  在 Finder 中右键点击任意文件夹，"
    echo "  即可看到「新建文件」菜单。"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    osascript -e 'display notification "在 Finder 右键菜单中即可使用「新建文件」功能" with title "RightHere 安装成功 ✓"' 2>/dev/null || true
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✓ 文件已安装到 /Applications"
    echo ""
    echo "  Finder 扩展暂时没有返回已启用状态。"
    echo "  如果右键菜单没有出现，请重启电脑后再试一次本安装程序。"
    echo ""
    echo "  在 Finder 中右键点击用户目录、桌面或文稿里的文件夹，"
    echo "  应该可以看到「新建文件」菜单。"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    osascript -e 'display notification "如果 Finder 右键菜单没有出现，请重启电脑后再运行一次安装程序。" with title "RightHere 已安装"' 2>/dev/null || true
fi

echo ""
read -p "按回车键关闭此窗口..." _
