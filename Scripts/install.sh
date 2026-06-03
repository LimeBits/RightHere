#!/usr/bin/env bash
# RightHere 安装脚本 — 双击「安装 RightHere.command」运行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="RightHere.app"
APP_SRC="${SCRIPT_DIR}/${APP_NAME}"
APP_DEST="/Applications/${APP_NAME}"
BUNDLE_ID="com.b-vibe.RightHere.Extension"

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
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister \
    -f -R -trusted "${APP_DEST}" 2>/dev/null || true

# ── 启动 app ──────────────────────────────────────────────────
echo "→ 启动 RightHere..."
open "${APP_DEST}"
sleep 3

# ── 激活 Finder 扩展 ──────────────────────────────────────────
echo "→ 激活 Finder 扩展..."
pluginkit -e use -i "${BUNDLE_ID}" 2>/dev/null || true
sleep 1

# ── 重启 Finder ───────────────────────────────────────────────
echo "→ 重启 Finder..."
killall Finder 2>/dev/null || true
sleep 1

# ── 验证结果 ──────────────────────────────────────────────────
STATUS=$(pluginkit -m -p com.apple.FinderSync 2>/dev/null | grep "${BUNDLE_ID}" || true)

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
    echo "  还需要一步手动操作："
    echo ""
    echo "  1. 打开「访达」→「应用程序」"
    echo "  2. 找到 RightHere，按住 Control 再点击"
    echo "  3. 选择「打开」，弹窗里再点「打开」"
    echo "  4. 完成后再次双击本安装脚本"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # 自动打开应用程序文件夹
    open /Applications
    osascript -e 'display alert "还需一步操作" message "请在「应用程序」文件夹中找到 RightHere，按住 Control 键点击它，选择「打开」，然后在弹出的对话框中点击「打开」。完成后再次双击安装脚本。" as warning' 2>/dev/null || true
fi

echo ""
read -p "按回车键关闭此窗口..." _
