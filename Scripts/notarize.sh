#!/usr/bin/env bash
# Notarize a RightHere .dmg or .app with Apple's notarytool, then staple it.
#
# Credentials:
#   Preferred: xcrun notarytool store-credentials "righthere-notary" ...
#   Or set:   NOTARIZE_APPLE_ID, NOTARIZE_TEAM_ID, NOTARIZE_PASSWORD

set -euo pipefail

if [[ $# -lt 1 ]]; then
    printf 'Usage: %s <path-to.dmg-or-.app>\n' "$(basename "$0")" >&2
    exit 1
fi

TARGET="$1"
if [[ ! -e "${TARGET}" ]]; then
    printf 'error: target not found: %s\n' "${TARGET}" >&2
    exit 1
fi

NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-${RIGHTHERE_NOTARIZE_PROFILE:-righthere-notary}}"

if xcrun notarytool history --keychain-profile "${NOTARIZE_PROFILE}" &>/dev/null; then
    AUTH_ARGS=(--keychain-profile "${NOTARIZE_PROFILE}")
    AUTH_MODE="profile"
    printf 'Using Keychain profile: %s\n' "${NOTARIZE_PROFILE}"
elif [[ -n "${NOTARIZE_APPLE_ID:-}" && -n "${NOTARIZE_TEAM_ID:-}" && -n "${NOTARIZE_PASSWORD:-}" ]]; then
    AUTH_ARGS=(--apple-id "${NOTARIZE_APPLE_ID}" --team-id "${NOTARIZE_TEAM_ID}" --password "${NOTARIZE_PASSWORD}")
    AUTH_MODE="environment"
    printf 'Using env-var notarization credentials.\n'
else
    printf 'error: no notarization credentials found.\n' >&2
    printf 'Create a Keychain profile once:\n' >&2
    printf '  xcrun notarytool store-credentials "%s" --apple-id "you@example.com" --team-id "WV6JA6UHLN" --password "app-specific-password"\n' "${NOTARIZE_PROFILE}" >&2
    printf 'Or set NOTARIZE_APPLE_ID, NOTARIZE_TEAM_ID, and NOTARIZE_PASSWORD.\n' >&2
    exit 1
fi

printf '\n%s\n' "-> Submitting $(basename "${TARGET}") to Apple notary service..."
SUBMIT_OUTPUT_FILE="$(mktemp "${TMPDIR:-/tmp}/righthere-notary-submit.XXXXXX.json")"
SUBMIT_ERROR_FILE="$(mktemp "${TMPDIR:-/tmp}/righthere-notary-submit.XXXXXX.log")"
cleanup() { rm -f "${SUBMIT_OUTPUT_FILE}" "${SUBMIT_ERROR_FILE}"; }
trap cleanup EXIT

if ! xcrun notarytool submit "${TARGET}" "${AUTH_ARGS[@]}" \
    --wait --timeout 30m --no-progress --output-format json \
    >"${SUBMIT_OUTPUT_FILE}" 2>"${SUBMIT_ERROR_FILE}"; then
    printf 'error: Apple notary submission command failed.\n' >&2
    [[ ! -s "${SUBMIT_ERROR_FILE}" ]] || cat "${SUBMIT_ERROR_FILE}" >&2
    [[ ! -s "${SUBMIT_OUTPUT_FILE}" ]] || cat "${SUBMIT_OUTPUT_FILE}" >&2
    exit 1
fi

cat "${SUBMIT_OUTPUT_FILE}"
printf '\n'

read -r STATUS SUBMISSION_ID < <(/usr/bin/python3 - "${SUBMIT_OUTPUT_FILE}" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload.get("status", ""), payload.get("id", ""))
PY
)

if [[ "${STATUS}" != "Accepted" ]]; then
    printf 'error: notarization status "%s"; not stapling.\n' "${STATUS}" >&2
    if [[ -n "${SUBMISSION_ID}" ]]; then
        if [[ "${AUTH_MODE}" == "profile" ]]; then
            printf 'Inspect the log with:\n  xcrun notarytool log %s --keychain-profile %s\n' "${SUBMISSION_ID}" "${NOTARIZE_PROFILE}" >&2
        else
            printf 'Inspect the log with:\n  xcrun notarytool log %s <same credentials>\n' "${SUBMISSION_ID}" >&2
        fi
    fi
    exit 1
fi

printf '\n%s\n' "-> Stapling ticket to $(basename "${TARGET}")..."
xcrun stapler staple "${TARGET}"
xcrun stapler validate "${TARGET}"

printf '\n%s\n' '-> Verifying Gatekeeper acceptance...'
if [[ "${TARGET}" == *.app ]]; then
    xcrun spctl --assess --type exec --verbose "${TARGET}"
else
    xcrun spctl --assess --type open --context context:primary-signature --verbose "${TARGET}"
fi

trap - EXIT
cleanup
printf '\n✓ Notarization complete: %s\n' "${TARGET}"
