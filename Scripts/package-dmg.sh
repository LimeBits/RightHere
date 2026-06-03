#!/usr/bin/env bash
# 打包 RightHere DMG 分发包
# 用法：./Scripts/package-dmg.sh [--build]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/RightHere.app"
DIST_DIR="${ROOT_DIR}/dist"
VOLUME_NAME="RightHere"
BUNDLE_ID="com.b-vibe.RightHere"

# ── 读取版本号 ────────────────────────────────────────────────
PLIST="${ROOT_DIR}/RightHere/Info.plist"
if [[ -f "${PLIST}" ]]; then
    APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST}" 2>/dev/null || echo "1.0")
else
    APP_VERSION="1.0"
fi
BUILD_TIMESTAMP="$(date '+%Y%m%d-%H%M')"
DMG_NAME="RightHere-${APP_VERSION}-${BUILD_TIMESTAMP}"
DMG_PATH="${DIST_DIR}/${DMG_NAME}.dmg"
DMG_RW_PATH="${DIST_DIR}/${DMG_NAME}-rw.dmg"
MOUNT_ROOT="${DIST_DIR}/dmg-mount"

# ── 先打包 app ────────────────────────────────────────────────
BUILD_FLAG=""
[[ "${1:-}" == "--build" ]] && BUILD_FLAG="--build"
"${ROOT_DIR}/Scripts/package-app.sh" ${BUILD_FLAG}

if [[ ! -d "${APP_DIR}" ]]; then
    printf '✗ RightHere.app 不存在，package-app.sh 可能失败\n' >&2
    exit 1
fi

# ── 准备工作目录 ──────────────────────────────────────────────
rm -rf "${MOUNT_ROOT}"
mkdir -p "${DIST_DIR}" "${MOUNT_ROOT}"
rm -f "${DMG_PATH}" "${DMG_RW_PATH}"

printf '→ 创建 DMG 镜像...\n'
/usr/bin/hdiutil create \
    -size 60m \
    -volname "${VOLUME_NAME}" \
    -ov \
    -fs "HFS+" \
    -layout SPUD \
    -type UDIF \
    "${DMG_RW_PATH}" >/dev/null

MOUNT_DIR="$(/usr/bin/mktemp -d "${MOUNT_ROOT}/RightHere.XXXXXX")"
/usr/bin/hdiutil attach "${DMG_RW_PATH}" -readwrite -noverify -noautoopen -mountpoint "${MOUNT_DIR}" >/dev/null

cleanup() {
    /usr/bin/hdiutil detach "${MOUNT_DIR}" -quiet 2>/dev/null || true
}
trap cleanup EXIT

# ── 拷贝内容 ──────────────────────────────────────────────────
printf '→ 填充 DMG 内容...\n'
/bin/cp -R "${APP_DIR}" "${MOUNT_DIR}/"
# 用 .command 后缀——macOS 双击会用 Terminal 执行，.sh 双击只会打开文本编辑器
/bin/cp "${ROOT_DIR}/Scripts/install.sh" "${MOUNT_DIR}/安装 RightHere.command"
chmod +x "${MOUNT_DIR}/安装 RightHere.command"

# Volume 图标
ICNS="${APP_DIR}/Contents/Resources/AppIcon.icns"
if [[ -f "${ICNS}" ]]; then
    cp "${ICNS}" "${MOUNT_DIR}/.VolumeIcon.icns"
    /usr/bin/SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true
    /usr/bin/SetFile -a V "${MOUNT_DIR}/.VolumeIcon.icns" 2>/dev/null || true
fi

# ── Finder 窗口布局（参考 LocalFlow 风格）────────────────────
/usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
  tell folder POSIX file "${MOUNT_DIR}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 100, 760, 460}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 120
    set text size of theViewOptions to 13
    set background color of theViewOptions to {56797, 56797, 61166}
    set position of item "RightHere.app" of container window to {170, 170}
    set position of item "安装 RightHere.command" of container window to {390, 170}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

# ── 压缩为只读 DMG ────────────────────────────────────────────
printf '→ 压缩 DMG...\n'
/usr/bin/hdiutil detach "${MOUNT_DIR}" -quiet
trap - EXIT

/usr/bin/hdiutil convert "${DMG_RW_PATH}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}" >/dev/null

rm -rf "${MOUNT_ROOT}"
rm -f "${DMG_RW_PATH}"

printf '\n✓ DMG 已生成: %s\n' "${DMG_PATH}"
APP_SIZE="$(du -sh "${DMG_PATH}" | awk '{print $1}')"
printf '  大小: %s\n' "${APP_SIZE}"
printf '\n分发方式：\n'
printf '  将 %s 发给朋友\n' "$(basename "${DMG_PATH}")"
printf '  朋友打开 DMG 后双击「安装 RightHere.command」即可\n'
