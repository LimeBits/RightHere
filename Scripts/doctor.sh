#!/usr/bin/env bash
# Diagnose the local RightHere development environment.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="${ROOT_DIR}/RightHere.xcodeproj/project.pbxproj"
APP_BUNDLE_ID="com.LimeBits.RightHere"
EXTENSION_BUNDLE_ID="com.LimeBits.RightHere.Extension"

section() {
    printf '\n== %s ==\n' "$1"
}

print_status() {
    local label="$1"
    local value="$2"
    printf '%-24s %s\n' "${label}:" "${value}"
}

section "System"
print_status "macOS" "$(sw_vers -productVersion 2>/dev/null || echo unknown)"
print_status "Architecture" "$(uname -m)"

section "Xcode"
if command -v xcodebuild >/dev/null 2>&1; then
    xcodebuild -version 2>/dev/null || true
else
    print_status "xcodebuild" "not found"
fi

section "Project"
configured_version="$(awk -F'= ' '/MARKETING_VERSION = / { gsub(/[;[:space:]]/, "", $2); print $2; exit }' "${PROJECT_FILE}" 2>/dev/null || true)"
deployment_target="$(awk -F'= ' '/MACOSX_DEPLOYMENT_TARGET = / { gsub(/[;[:space:]]/, "", $2); print $2; exit }' "${PROJECT_FILE}" 2>/dev/null || true)"
development_team="$(awk -F'= ' '/DEVELOPMENT_TEAM = / { gsub(/[;[:space:]\"]/, "", $2); print $2; exit }' "${PROJECT_FILE}" 2>/dev/null || true)"
print_status "Version" "${configured_version:-unknown}"
print_status "Deployment target" "${deployment_target:-unknown}"
print_status "Development team" "${development_team:-not set}"
print_status "Bundle ID" "${APP_BUNDLE_ID}"
print_status "Extension ID" "${EXTENSION_BUNDLE_ID}"

section "Build commands"
print_status "Native debug" "./deploy.sh --build --force"
print_status "Universal debug" "./deploy.sh --build --universal --force"
print_status "Release app" "./Scripts/package-app.sh --build --universal"
print_status "With local team" "DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --force"

section "Installed app"
if [[ -d "/Applications/RightHere.app" ]]; then
    installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/RightHere.app/Contents/Info.plist 2>/dev/null || true)"
    print_status "Path" "/Applications/RightHere.app"
    print_status "Version" "${installed_version:-unknown}"
else
    print_status "Path" "not installed"
fi

section "Finder extension"
extension_status="$(pluginkit -m -p com.apple.FinderSync 2>/dev/null | grep "${EXTENSION_BUNDLE_ID}" || true)"
if [[ -n "${extension_status}" ]]; then
    print_status "pluginkit" "${extension_status}"
else
    print_status "pluginkit" "not registered"
fi

if pgrep -x RightHereExtension >/dev/null 2>&1; then
    print_status "Process" "running"
else
    print_status "Process" "not running"
fi

section "Notes"
printf '%s\n' "Public distribution still requires Developer ID signing and notarization."
