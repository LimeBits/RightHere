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

if [[ -z "${RIGHTHERE_DEVELOPMENT_TEAM:-}" && -f "${ROOT_DIR}/Scripts/dev-identity.sh" ]]; then
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/Scripts/dev-identity.sh"
fi

TEAM_ID="${RIGHTHERE_DEVELOPMENT_TEAM:-${DEVELOPMENT_TEAM:-}}"
CODESIGN_IDENTITY="${RIGHTHERE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"
SKIP_NOTARIZE="${RIGHTHERE_SKIP_NOTARIZE:-0}"

if [[ -z "${TEAM_ID}" ]]; then
    printf 'error: missing Team ID. Set RIGHTHERE_DEVELOPMENT_TEAM or DEVELOPMENT_TEAM.\n' >&2
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
spctl --assess --type exec --verbose=4 "${EXPORTED_APP}"

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
    CODESIGN_IDENTITY="$(codesign -dvv "${EXPORTED_APP}" 2>&1 | awk -F= '/^Authority=Developer ID Application:/ { print $2; exit }')"
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
