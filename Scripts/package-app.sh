#!/usr/bin/env bash
# 编译并打包 RightHere.app（Apple Development 证书签名）
# 用法：./Scripts/package-app.sh [--build] [--universal]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/RightHere.app"
DERIVED_APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/RightHere-*/Build/Products/Release/RightHere.app 2>/dev/null | head -1 || true)
CERT="F44B0E057CE4BB69F80ACDF8EACF7B979416ED20"  # Apple Development: caoshihao@gmail.com
UNIVERSAL=false
for arg in "$@"; do [ "$arg" = "--universal" ] && UNIVERSAL=true; done

# ── 可选：先编译 ──────────────────────────────────────────────
if [[ "${1:-}" == "--build" ]]; then
    printf '→ 编译 Release build...\n'
    if [ "$UNIVERSAL" = true ]; then
        printf '  模式: Universal Binary (arm64 + x86_64)\n'
        xcodebuild \
            -project "${ROOT_DIR}/RightHere.xcodeproj" \
            -scheme RightHere \
            -configuration Release \
            ARCHS="arm64 x86_64" \
            ONLY_ACTIVE_ARCH=NO \
            build \
            2>&1 | grep -E "error:|warning:|Build succeeded|Build FAILED" | tail -20
    else
        printf '  模式: arm64\n'
        xcodebuild \
            -project "${ROOT_DIR}/RightHere.xcodeproj" \
            -scheme RightHere \
            -configuration Release \
            -arch arm64 \
            build \
            2>&1 | grep -E "error:|warning:|Build succeeded|Build FAILED" | tail -20
    fi
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
