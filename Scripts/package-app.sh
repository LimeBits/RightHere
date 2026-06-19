#!/usr/bin/env bash
# 编译并打包 RightHere.app（默认保留 Xcode build 产物签名）
# 用法：./Scripts/package-app.sh [--build] [--universal]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/RightHere.app"
DERIVED_APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/RightHere-*/Build/Products/Release/RightHere.app 2>/dev/null | head -1 || true)
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
UNIVERSAL=false
NATIVE_ARCH="$(uname -m)"

BUILD_SETTINGS=()
XCODEBUILD_FLAGS=()
if [[ -n "${DEVELOPMENT_TEAM}" ]]; then
    BUILD_SETTINGS+=(DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}")
    XCODEBUILD_FLAGS+=(-allowProvisioningUpdates)
fi
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
            "${XCODEBUILD_FLAGS[@]}" \
            ARCHS="arm64 x86_64" \
            ONLY_ACTIVE_ARCH=NO \
            "${BUILD_SETTINGS[@]}" \
            build \
            2>&1 | grep -E "error:|warning:|Build succeeded|Build FAILED" | tail -20 || true
    else
        printf '  模式: %s\n' "${NATIVE_ARCH}"
        xcodebuild \
            -project "${ROOT_DIR}/RightHere.xcodeproj" \
            -scheme RightHere \
            -configuration Release \
            "${XCODEBUILD_FLAGS[@]}" \
            -arch "${NATIVE_ARCH}" \
            "${BUILD_SETTINGS[@]}" \
            build \
            2>&1 | grep -E "error:|warning:|Build succeeded|Build FAILED" | tail -20 || true
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

# ── 清除隔离标记；如显式提供 CODESIGN_IDENTITY，则重签 ─────────
printf '→ 清除隔离标记...\n'
xattr -cr "${APP_DIR}"

if [[ -n "${CODESIGN_IDENTITY}" ]]; then
    printf '→ 使用指定证书重签 extension...\n'
    APPEX="${APP_DIR}/Contents/PlugIns/RightHereExtension.appex"
    if [[ -d "${APPEX}" ]]; then
        codesign --force --sign "${CODESIGN_IDENTITY}" --deep "${APPEX}"
    fi

    printf '→ 使用指定证书重签 app...\n'
    codesign --force --sign "${CODESIGN_IDENTITY}" "${APP_DIR}"
else
    printf '→ 未设置 CODESIGN_IDENTITY，保留 Xcode build 产物签名。\n'
fi

printf '✓ 打包完成: %s\n' "${APP_DIR}"
