#!/usr/bin/env bash
# Verify a specific, notarized RightHere release candidate before publishing it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_APP_ID="com.LimeBits.RightHere"
EXPECTED_EXTENSION_ID="com.LimeBits.RightHere.Extension"
TAG=""
DMG_PATH=""
NOTES_PATH=""
TEAM_ID="${RIGHTHERE_DEVELOPMENT_TEAM:-${DEVELOPMENT_TEAM:-}}"

usage() {
    cat <<'USAGE'
Usage: ./Scripts/release-preflight.sh --tag vX.Y.Z --dmg /path/to/RightHere.dmg --notes /path/to/release-notes.md

Checks the exact release candidate, not the newest file in dist/:
  - tag, project, app, and Finder Sync extension versions match
  - app and extension bundle identifiers and architectures are correct
  - both bundles have valid Developer ID signatures (and expected Team ID when set)
  - release notes contain only the current version
  - the DMG has a valid stapled notarization ticket
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag) TAG="${2:-}"; shift 2 ;;
        --dmg) DMG_PATH="${2:-}"; shift 2 ;;
        --notes) NOTES_PATH="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown argument: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ ! "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'error: --tag must look like vX.Y.Z.\n' >&2
    exit 1
fi
if [[ ! -f "${DMG_PATH}" || "${DMG_PATH}" != *.dmg ]]; then
    printf 'error: --dmg must name an existing .dmg file.\n' >&2
    exit 1
fi
if [[ ! -f "${NOTES_PATH}" ]]; then
    printf 'error: --notes must name an existing Markdown file.\n' >&2
    exit 1
fi

VERSION="${TAG#v}"
PROJECT_VERSIONS="$(grep -E '^[[:space:]]*MARKETING_VERSION:' "${ROOT_DIR}/project.yml" | sed -E 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*["'"'"']?([^"'"'"'[:space:]]+).*/\1/' | sort -u)"
PROJECT_VERSION_COUNT="$(printf '%s\n' "${PROJECT_VERSIONS}" | grep -c . || true)"
if [[ "${PROJECT_VERSION_COUNT}" != "1" || "${PROJECT_VERSIONS}" != "${VERSION}" ]]; then
    printf 'error: tag %s does not match a single MARKETING_VERSION in project.yml (%s).\n' "${TAG}" "${PROJECT_VERSIONS}" >&2
    exit 1
fi

NOTE_HEADER_COUNT="$(grep -Ec '^# RightHere [0-9]+\.[0-9]+\.[0-9]+(（中文）)?$' "${NOTES_PATH}" || true)"
if [[ "${NOTE_HEADER_COUNT}" != "2" ]]; then
    printf 'error: release notes must contain exactly two version headings for %s.\n' "${VERSION}" >&2
    exit 1
fi
if ! grep -Fxq "# RightHere ${VERSION}" "${NOTES_PATH}" || ! grep -Fxq "# RightHere ${VERSION}（中文）" "${NOTES_PATH}"; then
    printf 'error: release notes must contain English and Chinese headings for %s.\n' "${VERSION}" >&2
    exit 1
fi

printf '%s\n' '-> Verifying notarization ticket...'
xcrun stapler validate "${DMG_PATH}"

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/righthere-release.XXXXXX")"
cleanup() {
    hdiutil detach "${MOUNT_DIR}" -quiet 2>/dev/null || true
    rmdir "${MOUNT_DIR}" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach "${DMG_PATH}" -readonly -nobrowse -noverify -mountpoint "${MOUNT_DIR}" >/dev/null
APP_PATH="${MOUNT_DIR}/RightHere.app"
EXTENSION_PATH="${APP_PATH}/Contents/PlugIns/RightHereExtension.appex"
if [[ ! -d "${APP_PATH}" || ! -d "${EXTENSION_PATH}" ]]; then
    printf 'error: DMG must contain RightHere.app and its Finder Sync extension.\n' >&2
    exit 1
fi

plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }
assert_equal() {
    if [[ "$2" != "$3" ]]; then
        printf 'error: %s is %s; expected %s.\n' "$1" "$2" "$3" >&2
        exit 1
    fi
}

assert_equal 'App bundle identifier' "$(plist_value "${APP_PATH}" CFBundleIdentifier)" "${EXPECTED_APP_ID}"
assert_equal 'Extension bundle identifier' "$(plist_value "${EXTENSION_PATH}" CFBundleIdentifier)" "${EXPECTED_EXTENSION_ID}"
assert_equal 'App version' "$(plist_value "${APP_PATH}" CFBundleShortVersionString)" "${VERSION}"
assert_equal 'Extension version' "$(plist_value "${EXTENSION_PATH}" CFBundleShortVersionString)" "${VERSION}"
APP_BUILD="$(plist_value "${APP_PATH}" CFBundleVersion)"
assert_equal 'Extension build' "$(plist_value "${EXTENSION_PATH}" CFBundleVersion)" "${APP_BUILD}"

for bundle in "${APP_PATH}" "${EXTENSION_PATH}"; do
    codesign --verify --deep --strict --verbose=2 "${bundle}"
    signature="$(codesign -dvvv "${bundle}" 2>&1)"
    if ! grep -q '^Authority=Developer ID Application:' <<<"${signature}"; then
        printf 'error: %s is not signed by Developer ID Application.\n' "${bundle}" >&2
        exit 1
    fi
    if [[ -n "${TEAM_ID}" ]] && ! grep -q "^TeamIdentifier=${TEAM_ID}$" <<<"${signature}"; then
        printf 'error: %s is not signed by expected team %s.\n' "${bundle}" "${TEAM_ID}" >&2
        exit 1
    fi
done

for binary in "${APP_PATH}/Contents/MacOS/RightHere" "${EXTENSION_PATH}/Contents/MacOS/RightHereExtension"; do
    archs="$(lipo -archs "${binary}")"
    if [[ " ${archs} " != *' arm64 '* || " ${archs} " != *' x86_64 '* ]]; then
        printf 'error: %s is not universal: %s\n' "${binary}" "${archs}" >&2
        exit 1
    fi
done

printf '✓ Release candidate verified: %s (%s)\n' "${VERSION}" "${APP_BUILD}"
