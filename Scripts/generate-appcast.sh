#!/usr/bin/env bash
# Generate Sparkle appcast.xml for the latest RightHere DMG in dist/.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${RIGHTHERE_DIST_DIR:-${ROOT_DIR}/dist}"
APPCAST_DIR="${RIGHTHERE_APPCAST_DIR:-${DIST_DIR}/appcast}"

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
cp "${latest_dmg}" "${APPCAST_DIR}/"

"${GENERATE_APPCAST}" "${APPCAST_DIR}"
cp "${APPCAST_DIR}/appcast.xml" "${DIST_DIR}/appcast.xml"

printf '✓ Sparkle appcast ready:\n'
printf '  %s\n' "${DIST_DIR}/appcast.xml"
