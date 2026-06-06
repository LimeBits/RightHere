#!/usr/bin/env bash
# Compare the installed RightHere.app with this repository's configured version.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="${ROOT_DIR}/RightHere.xcodeproj/project.pbxproj"
INSTALLED_APP="${1:-/Applications/RightHere.app}"
PLIST="${INSTALLED_APP}/Contents/Info.plist"

configured_version="$(awk -F'= ' '/MARKETING_VERSION = / { gsub(/[;[:space:]]/, "", $2); print $2; exit }' "${PROJECT_FILE}")"
configured_build="$(awk -F'= ' '/CURRENT_PROJECT_VERSION = / { gsub(/[;[:space:]]/, "", $2); print $2; exit }' "${PROJECT_FILE}")"

printf 'Current project: RightHere %s (%s)\n' "${configured_version:-unknown}" "${configured_build:-unknown}"

if [[ ! -d "${INSTALLED_APP}" ]]; then
    printf 'Installed app: not found at %s\n' "${INSTALLED_APP}"
    exit 2
fi

installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST}" 2>/dev/null || true)"
installed_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${PLIST}" 2>/dev/null || true)"
icon_file="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "${PLIST}" 2>/dev/null || true)"
lsui_element="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "${PLIST}" 2>/dev/null || true)"

printf 'Installed app:  RightHere %s (%s)\n' "${installed_version:-unknown}" "${installed_build:-unknown}"
printf 'App icon:       %s\n' "${icon_file:-missing}"
printf 'Menu bar mode:  %s\n' "${lsui_element:-missing}"

if [[ "${installed_version}" == "${configured_version}" && "${installed_build}" == "${configured_build}" ]]; then
    printf 'Status: installed version matches this project.\n'
else
    printf 'Status: installed version is not the current project version.\n'
    exit 1
fi
