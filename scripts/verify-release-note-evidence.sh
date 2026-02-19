#!/bin/bash
set -euo pipefail

RELEASE_NOTES_SWIFT="${1:-rawctl/Models/ReleaseNotes.swift}"
EVIDENCE_MAP="${2:-docs/reports/2026-02-19-release-note-evidence.md}"

if [ ! -f "${RELEASE_NOTES_SWIFT}" ]; then
  echo "Missing release notes source: ${RELEASE_NOTES_SWIFT}"
  exit 1
fi

if [ ! -f "${EVIDENCE_MAP}" ]; then
  echo "Missing release-note evidence map: ${EVIDENCE_MAP}"
  exit 1
fi

LATEST_VERSION="$(rg -o 'version: \"[^\"]+\"' -m1 "${RELEASE_NOTES_SWIFT}" | sed -E 's/version: \"([^\"]+)\"/\1/')"
if [ -z "${LATEST_VERSION}" ]; then
  echo "Unable to read latest release-note version from ${RELEASE_NOTES_SWIFT}"
  exit 1
fi

if ! rg -q "^Version: ${LATEST_VERSION}$" "${EVIDENCE_MAP}"; then
  echo "Evidence map version mismatch: expected Version: ${LATEST_VERSION}"
  exit 1
fi

RELEASE_CLAIMS=()
while IFS= read -r claim; do
  RELEASE_CLAIMS+=("${claim}")
done < <(
  awk '
    /ReleaseNote\(/ {
      release_count++
      if (release_count == 1) {
        in_first_release = 1
      } else if (release_count == 2) {
        exit
      }
    }
    in_first_release { print }
  ' "${RELEASE_NOTES_SWIFT}" |
    rg '^\s*"[^"]+",?\s*$' |
    sed -E 's/^[[:space:]]*"//; s/",?[[:space:]]*$//' |
    sed '/^$/d'
)

if [ "${#RELEASE_CLAIMS[@]}" -eq 0 ]; then
  echo "No release-note claims extracted from latest release block."
  exit 1
fi

missing_claims=0
for claim in "${RELEASE_CLAIMS[@]}"; do
  if ! rg -F -- "- Claim: ${claim}" "${EVIDENCE_MAP}" >/dev/null; then
    echo "Missing evidence mapping for claim: ${claim}"
    missing_claims=1
  fi
done
if [ "${missing_claims}" -ne 0 ]; then
  exit 1
fi

mapped_claim_count="$(rg -c '^- Claim: ' "${EVIDENCE_MAP}")"
if [ "${mapped_claim_count}" -lt "${#RELEASE_CLAIMS[@]}" ]; then
  echo "Evidence map has fewer claims (${mapped_claim_count}) than release notes (${#RELEASE_CLAIMS[@]})."
  exit 1
fi

if ! awk '
  /^- Claim: / {
    if (expect_evidence == 1) {
      print "Missing Evidence line for claim: " previous_claim
      bad = 1
    }
    previous_claim = $0
    expect_evidence = 1
    next
  }
  expect_evidence == 1 && /^  Evidence: / {
    expect_evidence = 0
    next
  }
  END {
    if (expect_evidence == 1) {
      print "Missing Evidence line for claim: " previous_claim
      bad = 1
    }
    exit bad
  }
' "${EVIDENCE_MAP}"; then
  exit 1
fi

evidence_line_count="$(rg -c '^  Evidence: .*`[^`]+`' "${EVIDENCE_MAP}")"
if [ "${evidence_line_count}" -lt "${mapped_claim_count}" ]; then
  echo "Each claim must include at least one backticked code/test evidence reference."
  exit 1
fi

echo "Release-note evidence verification passed: ${EVIDENCE_MAP}"
