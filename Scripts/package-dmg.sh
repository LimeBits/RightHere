#!/usr/bin/env bash
# 打包 RightHere DMG 分发包
# 用法：./Scripts/package-dmg.sh [--build] [--universal] [--skip-signing] [--with-installer-script]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/RightHere.app"
DIST_DIR="${RIGHTHERE_DIST_DIR:-${ROOT_DIR}/dist}"
VOLUME_NAME="RightHere"
BUNDLE_ID="com.LimeBits.RightHere"
INCLUDE_INSTALLER_SCRIPT=false
BUILD_APP=false

MOUNT_ROOT="${DIST_DIR}/dmg-mount"

usage() {
    cat <<'USAGE'
Usage: ./Scripts/package-dmg.sh [options]

Options:
  --build                  Build Release app before creating the DMG.
  --universal              Build arm64 + x86_64 when used with --build.
  --skip-signing           Build without code signing for CI/internal checks.
  --with-installer-script  Include the optional install helper command.
  -h, --help               Show this help.

Environment:
  RIGHTHERE_DIST_DIR       Output directory. Defaults to ./dist.
  RIGHTHERE_DMG_SIZE       Override DMG image size, for example 80m.
  RIGHTHERE_DMG_SKIP_FINDER_LAYOUT=1
                           Skip Finder window layout scripting.

Without --build, the script packages an existing ./RightHere.app.
USAGE
}

# ── 先打包 app ────────────────────────────────────────────────
PACKAGE_APP_ARGS=()
for arg in "$@"; do
    case "${arg}" in
        --build)
            BUILD_APP=true
            PACKAGE_APP_ARGS+=("${arg}")
            ;;
        --universal|--skip-signing)
            PACKAGE_APP_ARGS+=("${arg}")
            ;;
        --with-installer-script)
            INCLUDE_INSTALLER_SCRIPT=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '✗ 未知参数: %s\n\n' "${arg}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "${BUILD_APP}" == true ]]; then
    "${ROOT_DIR}/Scripts/package-app.sh" ${PACKAGE_APP_ARGS[@]+"${PACKAGE_APP_ARGS[@]}"}
elif [[ -d "${APP_DIR}" ]]; then
    printf '→ 使用已有 app: %s\n' "${APP_DIR}"
else
    printf '✗ 找不到 %s\n' "${APP_DIR}" >&2
    printf '  请先运行: ./Scripts/package-dmg.sh --build --universal\n' >&2
    printf '  或先生成/复制 RightHere.app 到项目根目录。\n' >&2
    exit 1
fi

if [[ ! -d "${APP_DIR}" ]]; then
    printf '✗ RightHere.app 不存在，package-app.sh 可能失败\n' >&2
    exit 1
fi

APP_BIN="${APP_DIR}/Contents/MacOS/RightHere"
if [[ ! -f "${APP_BIN}" ]]; then
    printf '✗ 主可执行文件不存在: %s\n' "${APP_BIN}" >&2
    exit 1
fi

# ── 读取版本号 ────────────────────────────────────────────────
PLIST="${APP_DIR}/Contents/Info.plist"
APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST}" 2>/dev/null || echo "unknown")
APP_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${PLIST}" 2>/dev/null || echo "unknown")
BUILD_TIMESTAMP="$(date '+%Y%m%d-%H%M')"
DMG_NAME="RightHere-${APP_VERSION}-build${APP_BUILD}-${BUILD_TIMESTAMP}"
DMG_PATH="${DIST_DIR}/${DMG_NAME}.dmg"
DMG_RW_PATH="${DIST_DIR}/${DMG_NAME}-rw.dmg"

APP_SIZE_MB="$(du -sm "${APP_DIR}" | awk '{print $1}')"
DMG_SIZE="${RIGHTHERE_DMG_SIZE:-$(( APP_SIZE_MB + 60 ))m}"
if (( APP_SIZE_MB + 60 < 80 )); then
    DMG_SIZE="${RIGHTHERE_DMG_SIZE:-80m}"
fi

# ── 准备工作目录 ──────────────────────────────────────────────
rm -rf "${MOUNT_ROOT}"
mkdir -p "${DIST_DIR}" "${MOUNT_ROOT}"
rm -f "${DMG_PATH}" "${DMG_RW_PATH}"

printf '→ 创建 DMG 镜像...\n'
printf '  App 版本: %s (%s)\n' "${APP_VERSION}" "${APP_BUILD}"
printf '  镜像大小: %s\n' "${DMG_SIZE}"
/usr/bin/hdiutil create \
    -size "${DMG_SIZE}" \
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
/bin/ln -s /Applications "${MOUNT_DIR}/Applications"
if [[ "${INCLUDE_INSTALLER_SCRIPT}" == true ]]; then
    # 可选的一键安装脚本：内部测试时可自动复制、启动、启用扩展并重启 Finder。
    # 用 .command 后缀，macOS 双击会用 Terminal 执行；.sh 双击只会打开文本编辑器。
    /bin/cp "${ROOT_DIR}/Scripts/install.sh" "${MOUNT_DIR}/安装并启用 RightHere.command"
    chmod +x "${MOUNT_DIR}/安装并启用 RightHere.command"
fi

# Volume 图标
ICNS="${APP_DIR}/Contents/Resources/AppIcon.icns"
if [[ -f "${ICNS}" ]]; then
    cp "${ICNS}" "${MOUNT_DIR}/.VolumeIcon.icns"
    /usr/bin/SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true
    /usr/bin/SetFile -a V "${MOUNT_DIR}/.VolumeIcon.icns" 2>/dev/null || true
fi

# ── Finder 窗口布局（参考 LocalFlow 风格）────────────────────
INSTALLER_POSITION_SCRIPT=""
if [[ "${INCLUDE_INSTALLER_SCRIPT}" == true ]]; then
    INSTALLER_POSITION_SCRIPT='    set position of item "安装并启用 RightHere.command" of container window to {330, 310}'
fi

if [[ -n "${CI:-}" || "${RIGHTHERE_DMG_SKIP_FINDER_LAYOUT:-}" == "1" ]]; then
    printf '→ 跳过 Finder 窗口布局。\n'
else
    printf '→ 设置 Finder 拖拽安装布局...\n'
    /usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
  tell folder POSIX file "${MOUNT_DIR}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {180, 90, 840, 530}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set text size of theViewOptions to 13
    set background color of theViewOptions to {56797, 56797, 61166}
    set position of item "RightHere.app" of container window to {205, 190}
    set position of item "Applications" of container window to {455, 190}
${INSTALLER_POSITION_SCRIPT}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT
fi

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

(
    cd "${DIST_DIR}"
    /usr/bin/shasum -a 256 "$(basename "${DMG_PATH}")" > "$(basename "${DMG_PATH}").sha256"
)

printf '\n✓ DMG 已生成: %s\n' "${DMG_PATH}"
APP_SIZE="$(du -sh "${DMG_PATH}" | awk '{print $1}')"
printf '  大小: %s\n' "${APP_SIZE}"
printf '  校验: %s.sha256\n' "${DMG_PATH}"
printf '\n分发方式：\n'
printf '  将 %s 发给朋友\n' "$(basename "${DMG_PATH}")"
if [[ "${INCLUDE_INSTALLER_SCRIPT}" == true ]]; then
    printf '  推荐双击「安装并启用 RightHere.command」，它会安装 App、启用 Finder 扩展并重启 Finder\n'
else
    printf '  推荐拖动 RightHere.app 到 Applications\n'
fi
