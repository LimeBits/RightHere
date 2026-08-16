#!/usr/bin/env bash
# 编译并打包 RightHere.app（默认保留 Xcode build 产物签名）
# 用法：./Scripts/package-app.sh [--build] [--universal] [--skip-signing]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/RightHere.app"
DERIVED_APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/RightHere-*/Build/Products/Release/RightHere.app 2>/dev/null | head -1 || true)
if [[ -z "${RIGHTHERE_CODESIGN_IDENTITY:-}" && -f "${ROOT_DIR}/Scripts/dev-identity.sh" ]]; then
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/Scripts/dev-identity.sh"
fi
CODESIGN_IDENTITY="${RIGHTHERE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"
if [[ -z "${CODESIGN_IDENTITY}" && "${RIGHTHERE_USE_LOCAL_CODESIGN:-0}" == "1" ]]; then
    CODESIGN_IDENTITY="${RIGHTHERE_CODESIGN_IDENTITY:-}"
fi
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-${RIGHTHERE_DEVELOPMENT_TEAM:-}}"
UNIVERSAL=false
SKIP_SIGNING=false
NATIVE_ARCH="$(uname -m)"
APP_ENTITLEMENTS="${ROOT_DIR}/RightHere/RightHere.entitlements"
EXTENSION_ENTITLEMENTS="${ROOT_DIR}/RightHereExtension/RightHereExtension.entitlements"

BUILD_SETTINGS=()
XCODEBUILD_FLAGS=()
if [[ -n "${DEVELOPMENT_TEAM}" ]]; then
    BUILD_SETTINGS+=(DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}")
    XCODEBUILD_FLAGS+=(-allowProvisioningUpdates)
fi
for arg in "$@"; do
    case "${arg}" in
        --universal)
            UNIVERSAL=true
            ;;
        --skip-signing)
            SKIP_SIGNING=true
            ;;
    esac
done

if [[ "${SKIP_SIGNING}" == true ]]; then
    BUILD_SETTINGS+=(
        CODE_SIGNING_ALLOWED=NO
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGN_IDENTITY=
    )
fi

run_xcodebuild() {
    local build_log
    build_log="$(mktemp "${TMPDIR:-/tmp}/righthere-xcodebuild.XXXXXX")"

    if ! xcodebuild "$@" >"${build_log}" 2>&1; then
        grep -E "error:|warning:|Build succeeded|Build FAILED" "${build_log}" | tail -60 || true
        printf '✗ xcodebuild failed. Full log: %s\n' "${build_log}" >&2
        return 1
    fi

    grep -E "error:|warning:|Build succeeded|Build FAILED" "${build_log}" | tail -20 || true
    rm -f "${build_log}"
}

# ── 可选：先编译 ──────────────────────────────────────────────
if [[ "${1:-}" == "--build" ]]; then
    printf '→ 编译 Release build...\n'
    if [ "$UNIVERSAL" = true ]; then
        printf '  模式: Universal Binary (arm64 + x86_64)\n'
        run_xcodebuild \
            -project "${ROOT_DIR}/RightHere.xcodeproj" \
            -scheme RightHere \
            -configuration Release \
            ${XCODEBUILD_FLAGS[@]+"${XCODEBUILD_FLAGS[@]}"} \
            ARCHS="arm64 x86_64" \
            ONLY_ACTIVE_ARCH=NO \
            ${BUILD_SETTINGS[@]+"${BUILD_SETTINGS[@]}"} \
            build
    else
        printf '  模式: %s\n' "${NATIVE_ARCH}"
        run_xcodebuild \
            -project "${ROOT_DIR}/RightHere.xcodeproj" \
            -scheme RightHere \
            -configuration Release \
            ${XCODEBUILD_FLAGS[@]+"${XCODEBUILD_FLAGS[@]}"} \
            -arch "${NATIVE_ARCH}" \
            ${BUILD_SETTINGS[@]+"${BUILD_SETTINGS[@]}"} \
            build
    fi
    DERIVED_APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/RightHere-*/Build/Products/Release/RightHere.app 2>/dev/null | head -1 || true)
fi

if [[ -z "${DERIVED_APP}" ]]; then
    printf '✗ 找不到 Release build 产物，请先运行 ./Scripts/package-app.sh --build\n' >&2
    exit 1
fi

DERIVED_BIN="${DERIVED_APP}/Contents/MacOS/RightHere"
DERIVED_EXTENSION_BIN="${DERIVED_APP}/Contents/PlugIns/RightHereExtension.appex/Contents/MacOS/RightHereExtension"
if [[ ! -f "${DERIVED_BIN}" ]]; then
    printf '✗ 主可执行文件不存在: %s\n' "${DERIVED_BIN}" >&2
    exit 1
fi

if [[ "${UNIVERSAL}" == true ]]; then
    for binary in "${DERIVED_BIN}" "${DERIVED_EXTENSION_BIN}"; do
        if [[ ! -f "${binary}" ]] || ! lipo -archs "${binary}" 2>/dev/null | grep -qw arm64 || ! lipo -archs "${binary}" 2>/dev/null | grep -qw x86_64; then
            printf '✗ Universal build 缺少 arm64 或 x86_64 架构: %s\n' "${binary}" >&2
            exit 1
        fi
    done
fi

printf '→ 复制 app...\n'
rm -rf "${APP_DIR}"
cp -R "${DERIVED_APP}" "${APP_DIR}"

# ── 清除隔离标记；如显式提供 CODESIGN_IDENTITY，则重签 ─────────
printf '→ 清除隔离标记...\n'
xattr -cr "${APP_DIR}"

if [[ "${SKIP_SIGNING}" == true ]]; then
    printf '→ 已启用 --skip-signing，跳过重签。\n'
elif [[ -n "${CODESIGN_IDENTITY}" ]]; then
    printf '→ 使用指定证书重签 extension...\n'
    APPEX="${APP_DIR}/Contents/PlugIns/RightHereExtension.appex"
    if [[ -d "${APPEX}" ]]; then
        codesign --force --sign "${CODESIGN_IDENTITY}" \
            --options runtime \
            --timestamp \
            --entitlements "${EXTENSION_ENTITLEMENTS}" \
            --deep \
            "${APPEX}"
    fi

    printf '→ 使用指定证书重签 app...\n'
    codesign --force --sign "${CODESIGN_IDENTITY}" \
        --options runtime \
        --timestamp \
        --entitlements "${APP_ENTITLEMENTS}" \
        "${APP_DIR}"
else
    printf '→ 未设置 CODESIGN_IDENTITY，保留 Xcode build 产物签名。\n'
fi

printf '✓ 打包完成: %s\n' "${APP_DIR}"
