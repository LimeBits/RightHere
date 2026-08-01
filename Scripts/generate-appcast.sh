#!/usr/bin/env bash
# Generate Sparkle appcast.xml for the latest RightHere DMG in dist/.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${RIGHTHERE_DIST_DIR:-${ROOT_DIR}/dist}"
APPCAST_DIR="${RIGHTHERE_APPCAST_DIR:-${DIST_DIR}/appcast}"
DOWNLOAD_URL_PREFIX="${RIGHTHERE_DOWNLOAD_URL_PREFIX:-https://github.com/LimeBits/RightHere/releases/latest/download/}"

if [[ -f "${ROOT_DIR}/.dev.vars" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/.dev.vars"
    set +a
fi

GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-}"

if [[ -z "${GENERATE_APPCAST}" ]]; then
    for candidate in \
        "${ROOT_DIR}/Vendor/Sparkle/bin/generate_appcast" \
        "${ROOT_DIR}/.build/artifacts/sparkle/Sparkle/bin/generate_appcast" \
        "/opt/homebrew/bin/generate_appcast" \
        "/usr/local/bin/generate_appcast"; do
        if [[ -x "${candidate}" ]]; then
            GENERATE_APPCAST="${candidate}"
            break
        fi
    done
fi

if [[ -z "${GENERATE_APPCAST}" || ! -x "${GENERATE_APPCAST}" ]]; then
    printf 'error: Sparkle generate_appcast tool not found.\n' >&2
    printf 'Set SPARKLE_GENERATE_APPCAST=/path/to/generate_appcast and retry.\n' >&2
    exit 1
fi

latest_dmg="$(ls -t "${DIST_DIR}"/RightHere-*.dmg 2>/dev/null | head -1 || true)"
if [[ -z "${latest_dmg}" ]]; then
    printf 'error: no RightHere DMG found in %s\n' "${DIST_DIR}" >&2
    exit 1
fi

rm -rf "${APPCAST_DIR}"
mkdir -p "${APPCAST_DIR}"
latest_dmg_name="$(basename "${latest_dmg}")"
cp "${latest_dmg}" "${APPCAST_DIR}/"

release_notes_path="${APPCAST_DIR}/${latest_dmg_name%.dmg}.md"
cat >"${release_notes_path}" <<'MARKDOWN'
# RightHere 0.1.12

## 修复

- 修复 Sparkle 能发现更新、但安装阶段失败的问题。
- 补齐 sandbox App 使用 Sparkle installer 所需的权限配置。
- 更新包在解压前进行签名校验，并要求 signed appcast。

## 优化

- 更新窗口显示更完整的版本说明。
- 保留自动检查更新，仍可在设置中关闭。
MARKDOWN

"${GENERATE_APPCAST}" \
    --embed-release-notes \
    --download-url-prefix "${DOWNLOAD_URL_PREFIX}" \
    "${APPCAST_DIR}"
cp "${APPCAST_DIR}/appcast.xml" "${DIST_DIR}/appcast.xml"

if ! grep -q 'sparkle:edSignature=' "${DIST_DIR}/appcast.xml"; then
    printf 'error: generated appcast is missing sparkle:edSignature.\n' >&2
    printf 'Run Sparkle generate_keys once and make sure the private EdDSA key is available in Keychain.\n' >&2
    exit 1
fi

if ! grep -q 'sparkle-signatures:' "${DIST_DIR}/appcast.xml"; then
    printf 'error: generated appcast is missing signed feed metadata.\n' >&2
    printf 'RightHere requires SURequireSignedFeed for release builds.\n' >&2
    exit 1
fi

if ! grep -q 'enclosure url="https://' "${DIST_DIR}/appcast.xml"; then
    printf 'error: generated appcast does not contain an absolute HTTPS download URL.\n' >&2
    printf 'Set RIGHTHERE_DOWNLOAD_URL_PREFIX to the release asset URL prefix and retry.\n' >&2
    exit 1
fi

printf '✓ Sparkle appcast ready:\n'
printf '  %s\n' "${DIST_DIR}/appcast.xml"
