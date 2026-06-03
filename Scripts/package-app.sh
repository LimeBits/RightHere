#!/usr/bin/env bash
# 编译并打包 RightHere.app（ad-hoc 签名，无需 Developer ID）
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/RightHere.app"
DERIVED_APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/RightHere-*/Build/Products/Release/RightHere.app 2>/dev/null | head -1 || true)

CERT="F44B0E057CE4BB69F80ACDF8EACF7B979416ED20"  # Apple Development: caoshihao@gmail.com

# ── 可选：先编译 ──────────────────────────────────────────────
if [[ "${1:-}" == "--build" ]]; then
    printf '→ 编译 Release build...\n'
    xcodebuild \
        -project "${ROOT_DIR}/RightHere.xcodeproj" \
        -scheme RightHere \
        -configuration Release \
        -arch arm64 \
        build \
        2>&1 | grep -E "error:|warning:|Build succeeded|Build FAILED" | tail -20
    DERIVED_APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/RightHere-*/Build/Products/Release/RightHere.app 2>/dev/null | head -1 || true)
fi

if [[ -z "${DERIVED_APP}" ]]; then
    printf '✗ 找不到 Release build 产物，请先运行 ./Scripts/package-app.sh --build\n' >&2
    exit 1
fi

DERIVED_BIN="${DERIVED_APP}/Contents/MacOS/RightHere"
if [[ ! -f "${DERIVED_BIN}" ]]; then
    printf '✗ 主可执行文件不存在: %s\n' "${DERIVED_BIN}" >&2
    exit 1
fi

printf '→ 复制 app...\n'
rm -rf "${APP_DIR}"
cp -R "${DERIVED_APP}" "${APP_DIR}"

# ── 生成 .icns ────────────────────────────────────────────────
ICONSET_DIR="${ROOT_DIR}/RightHere/Assets.xcassets/AppIcon.appiconset"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
mkdir -p "${RESOURCES_DIR}"

if [[ -d "${ICONSET_DIR}" ]] && ls "${ICONSET_DIR}"/*.png &>/dev/null; then
    printf '→ 生成 AppIcon.icns...\n'
    TMP_ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "${TMP_ICONSET}"
    for size in 16 32 128 256 512; do
        src="${ICONSET_DIR}/icon_${size}x${size}.png"
        src2x="${ICONSET_DIR}/icon_$((size*2))x$((size*2)).png"
        [[ -f "${src}" ]]   && cp "${src}"   "${TMP_ICONSET}/icon_${size}x${size}.png"
        [[ -f "${src2x}" ]] && cp "${src2x}" "${TMP_ICONSET}/icon_${size}x${size}@2x.png"
    done
    iconutil -c icns "${TMP_ICONSET}" -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf "$(dirname "${TMP_ICONSET}")"

    # 把图标文件名写入 Info.plist，否则系统找不到
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "${APP_DIR}/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_DIR}/Contents/Info.plist"
fi

# ── 清除隔离标记 + ad-hoc 签名 ────────────────────────────────
printf '→ 清除隔离标记...\n'
xattr -cr "${APP_DIR}"

printf '→ 用 Apple Development 证书签名 extension...\n'
APPEX="${APP_DIR}/Contents/PlugIns/RightHereExtension.appex"
if [[ -d "${APPEX}" ]]; then
    codesign --force --sign "${CERT}" --deep "${APPEX}"
fi

printf '→ 用 Apple Development 证书签名 app...\n'
codesign --force --sign "${CERT}" "${APP_DIR}"

printf '✓ 打包完成: %s\n' "${APP_DIR}"
