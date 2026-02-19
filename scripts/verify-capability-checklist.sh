#!/bin/bash
set -euo pipefail

CHECKLIST_PATH="${1:-docs/plans/2026-02-19-capability-checklist.md}"

if [ ! -f "${CHECKLIST_PATH}" ]; then
  echo "Missing checklist: ${CHECKLIST_PATH}"
  exit 1
fi

if rg -n "^- \\[ \\]" "${CHECKLIST_PATH}" >/dev/null; then
  echo "Checklist has unchecked blocking items:"
  rg -n "^- \\[ \\]" "${CHECKLIST_PATH}"
  exit 1
fi

if [ "$(rg -n "^  Evidence:" "${CHECKLIST_PATH}" | wc -l | tr -d ' ')" -eq 0 ]; then
  echo "Checklist does not contain evidence lines."
  exit 1
fi

echo "Capability checklist verification passed: ${CHECKLIST_PATH}"
