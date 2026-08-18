#!/usr/bin/env bash
# Generate Sparkle appcast.xml for an explicitly selected RightHere DMG.
# Refusing to guess the newest dist/ artifact prevents a release from pairing
# the wrong binary and release notes.
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

DMG_PATH=""
RELEASE_TAG=""
NOTES_SOURCE="${ROOT_DIR}/RELEASE_NOTES.md"

usage() {
    cat <<'USAGE'
Usage: ./Scripts/generate-appcast.sh --dmg /path/to/RightHere.dmg --tag vX.Y.Z [--notes /path/to/notes.md]

The DMG, tag, and notes are explicit so a stale file in dist/ cannot become an update.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg) DMG_PATH="${2:-}"; shift 2 ;;
        --tag) RELEASE_TAG="${2:-}"; shift 2 ;;
        --notes) NOTES_SOURCE="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown argument: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ ! "${RELEASE_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'error: --tag must look like vX.Y.Z.\n' >&2
    exit 1
fi
if [[ ! -f "${DMG_PATH}" || "${DMG_PATH}" != *.dmg ]]; then
    printf 'error: --dmg must name an existing .dmg file.\n' >&2
    exit 1
fi
if [[ ! -f "${NOTES_SOURCE}" ]]; then
    printf 'error: --notes must name an existing Markdown file.\n' >&2
    exit 1
fi

RELEASE_VERSION="${RELEASE_TAG#v}"
if [[ "$(basename "${DMG_PATH}")" != *"-${RELEASE_VERSION}-"* ]]; then
    printf 'error: DMG filename does not identify release version %s.\n' "${RELEASE_VERSION}" >&2
    exit 1
fi
NOTE_HEADER_COUNT="$(grep -Ec '^# RightHere [0-9]+\.[0-9]+\.[0-9]+(（中文）)?$' "${NOTES_SOURCE}" || true)"
if [[ "${NOTE_HEADER_COUNT}" != "2" ]]; then
    printf 'error: notes must contain exactly two version headings for %s.\n' "${RELEASE_VERSION}" >&2
    exit 1
fi
if ! grep -Fxq "# RightHere ${RELEASE_VERSION}" "${NOTES_SOURCE}" || ! grep -Fxq "# RightHere ${RELEASE_VERSION}（中文）" "${NOTES_SOURCE}"; then
    printf 'error: notes must contain English and Chinese headings for %s.\n' "${RELEASE_VERSION}" >&2
    exit 1
fi

# An appcast is a publishable update artifact. Do not generate one unless the
# exact DMG has passed the same release-candidate checks described in the docs.
"${ROOT_DIR}/Scripts/release-preflight.sh" \
    --tag "${RELEASE_TAG}" \
    --dmg "${DMG_PATH}" \
    --notes "${NOTES_SOURCE}"

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

latest_dmg="${DMG_PATH}"
if [[ -z "${latest_dmg}" ]]; then
    printf 'error: no release DMG was provided.\n' >&2
    exit 1
fi

rm -rf "${APPCAST_DIR}"
mkdir -p "${APPCAST_DIR}"
latest_dmg_name="$(basename "${latest_dmg}")"
cp "${latest_dmg}" "${APPCAST_DIR}/"

release_notes_path="${APPCAST_DIR}/${latest_dmg_name%.dmg}.md"
if [[ -f "${NOTES_SOURCE}" ]]; then
    cp "${NOTES_SOURCE}" "${release_notes_path}"
else
    printf 'error: checked release notes disappeared: %s\n' "${NOTES_SOURCE}" >&2
    exit 1
fi

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
