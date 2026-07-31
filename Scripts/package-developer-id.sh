#!/usr/bin/env bash
# Build a formal Developer ID distribution DMG for RightHere.
#
# This is the cross-machine path:
#   1. xcodebuild archive
#   2. xcodebuild -exportArchive with method=developer-id
#   3. package exported RightHere.app into a DMG
#   4. sign the DMG
#   5. notarize and staple the DMG

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${RIGHTHERE_DIST_DIR:-${ROOT_DIR}/dist}"
ARCHIVE_DIR="${DIST_DIR}/archives"
EXPORT_DIR="${DIST_DIR}/developer-id-export"
EXPORT_OPTIONS="${DIST_DIR}/ExportOptions-DeveloperID.plist"
ARCHIVE_PATH="${ARCHIVE_DIR}/RightHere.xcarchive"
APP_DIR="${ROOT_DIR}/RightHere.app"

if [[ -f "${ROOT_DIR}/.dev.vars" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/.dev.vars"
    set +a
fi

if [[ -z "${RIGHTHERE_DEVELOPMENT_TEAM:-}" && -f "${ROOT_DIR}/Scripts/dev-identity.sh" ]]; then
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/Scripts/dev-identity.sh"
fi

TEAM_ID="${RIGHTHERE_DEVELOPMENT_TEAM:-${DEVELOPMENT_TEAM:-}}"
CODESIGN_IDENTITY="${RIGHTHERE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"
SKIP_NOTARIZE="${RIGHTHERE_SKIP_NOTARIZE:-0}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

if [[ -z "${TEAM_ID}" ]]; then
    printf 'error: missing Team ID. Set RIGHTHERE_DEVELOPMENT_TEAM or DEVELOPMENT_TEAM.\n' >&2
    exit 1
fi
if [[ -z "${SPARKLE_PUBLIC_ED_KEY}" ]]; then
    printf 'error: missing Sparkle public EdDSA key. Set SPARKLE_PUBLIC_ED_KEY before release packaging.\n' >&2
    printf 'Generate it once with Sparkle generate_keys, then keep the private key in Keychain.\n' >&2
    exit 1
fi

mkdir -p "${DIST_DIR}" "${ARCHIVE_DIR}"
rm -rf "${ARCHIVE_PATH}" "${EXPORT_DIR}" "${EXPORT_OPTIONS}"

if command -v xcodegen >/dev/null 2>&1; then
    printf '%s\n' '-> Regenerating Xcode project with XcodeGen...'
    (cd "${ROOT_DIR}" && xcodegen generate)
fi

printf '%s\n' '-> Archiving RightHere for Developer ID export...'
xcodebuild \
    -project "${ROOT_DIR}/RightHere.xcodeproj" \
    -scheme RightHere \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "${ARCHIVE_PATH}" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY}" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    -allowProvisioningUpdates \
    archive

cat >"${EXPORT_OPTIONS}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

printf '%s\n' '-> Exporting archive with Developer ID signing...'
if ! xcodebuild \
    -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -allowProvisioningUpdates; then
    printf '\nDeveloper ID export failed.\n' >&2
    printf 'Check these in Xcode before retrying:\n' >&2
    printf '  1. Xcode Settings -> Accounts has a valid Apple Developer account.\n' >&2
    printf '  2. Developer ID Application certificate is valid and has its private key.\n' >&2
    printf '  3. Developer ID provisioning profiles exist for:\n' >&2
    printf '     - com.LimeBits.RightHere\n' >&2
    printf '     - com.LimeBits.RightHere.Extension\n' >&2
    printf '  4. App Group group.com.LimeBits.RightHere is enabled for both identifiers.\n' >&2
    exit 1
fi

EXPORTED_APP="${EXPORT_DIR}/RightHere.app"
if [[ ! -d "${EXPORTED_APP}" ]]; then
    printf 'error: exported app not found: %s\n' "${EXPORTED_APP}" >&2
    exit 1
fi

printf '%s\n' '-> Verifying exported app signature...'
codesign --verify --deep --strict --verbose=4 "${EXPORTED_APP}"
SIGNATURE_INFO="$(codesign -dvv "${EXPORTED_APP}" 2>&1)"
printf '%s\n' "${SIGNATURE_INFO}" | grep -E '^(Authority|TeamIdentifier|Runtime Version)=' || true
if ! printf '%s\n' "${SIGNATURE_INFO}" | grep -q '^Authority=Developer ID Application:'; then
    printf 'error: exported app is not signed with Developer ID Application.\n' >&2
    printf 'Run this from the same macOS account that has the Developer ID Application private key in Keychain.\n' >&2
    exit 1
fi
printf '%s\n' '-> Developer ID signature is present; Gatekeeper verification runs after notarization.'

printf '%s\n' '-> Verifying Sparkle update metadata...'
EXPORTED_INFO_PLIST="${EXPORTED_APP}/Contents/Info.plist"
EXPORTED_FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "${EXPORTED_INFO_PLIST}" 2>/dev/null || true)"
EXPORTED_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "${EXPORTED_INFO_PLIST}" 2>/dev/null || true)"
if [[ -z "${EXPORTED_FEED_URL}" ]]; then
    printf 'error: exported app is missing SUFeedURL in Info.plist.\n' >&2
    exit 1
fi
if [[ -z "${EXPORTED_PUBLIC_KEY}" || "${EXPORTED_PUBLIC_KEY}" != "${SPARKLE_PUBLIC_ED_KEY}" ]]; then
    printf 'error: exported app has an invalid SUPublicEDKey in Info.plist.\n' >&2
    exit 1
fi

printf '%s\n' '-> Verifying universal binaries...'
APP_ARCHS="$(lipo -archs "${EXPORTED_APP}/Contents/MacOS/RightHere")"
APPEX_ARCHS="$(lipo -archs "${EXPORTED_APP}/Contents/PlugIns/RightHereExtension.appex/Contents/MacOS/RightHereExtension")"
printf '   App: %s\n' "${APP_ARCHS}"
printf '   Extension: %s\n' "${APPEX_ARCHS}"
if [[ " ${APP_ARCHS} " != *" arm64 "* || " ${APP_ARCHS} " != *" x86_64 "* ]]; then
    printf 'error: RightHere.app is not universal.\n' >&2
    exit 1
fi
if [[ " ${APPEX_ARCHS} " != *" arm64 "* || " ${APPEX_ARCHS} " != *" x86_64 "* ]]; then
    printf 'error: RightHereExtension.appex is not universal.\n' >&2
    exit 1
fi

if [[ -z "${CODESIGN_IDENTITY}" ]]; then
    CODESIGN_IDENTITY="$(printf '%s\n' "${SIGNATURE_INFO}" | awk -F= '/^Authority=Developer ID Application:/ && !found { print $2; found=1 }')"
fi

printf '%s\n' '-> Staging exported app for DMG packaging...'
rm -rf "${APP_DIR}"
cp -R "${EXPORTED_APP}" "${APP_DIR}"
xattr -cr "${APP_DIR}"

RIGHTHERE_DMG_SKIP_FINDER_LAYOUT="${RIGHTHERE_DMG_SKIP_FINDER_LAYOUT:-1}" \
    "${ROOT_DIR}/Scripts/package-dmg.sh" --with-installer-script

DMG_PATH="$(ls -t "${DIST_DIR}"/RightHere-*.dmg | head -1)"

if [[ -n "${CODESIGN_IDENTITY}" ]]; then
    printf '%s\n' '-> Signing DMG with Developer ID...'
    codesign --force --sign "${CODESIGN_IDENTITY}" --timestamp "${DMG_PATH}"
else
    printf 'warning: no local Developer ID identity available for DMG signing; continuing with the Developer ID signed app inside the DMG.\n' >&2
fi

if [[ "${SKIP_NOTARIZE}" == "1" ]]; then
    printf 'Skipping notarization because RIGHTHERE_SKIP_NOTARIZE=1\n'
else
    printf '%s\n' '-> Notarizing and stapling DMG...'
    "${ROOT_DIR}/Scripts/notarize.sh" "${DMG_PATH}"
fi

(
    cd "${DIST_DIR}"
    shasum -a 256 "$(basename "${DMG_PATH}")" > "$(basename "${DMG_PATH}").sha256"
)

printf '\n✓ Developer ID package ready:\n'
printf '  %s\n' "${DMG_PATH}"
printf '  %s.sha256\n' "${DMG_PATH}"
