#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-build}"
OUT_DIR="${BUILD_DIR}/ios_ci_report"
mkdir -p "${OUT_DIR}"

LOG_FILE="${BUILD_DIR}/xcodebuild.log"
XCBUNDLE="$(
  /usr/bin/find "${BUILD_DIR}" -maxdepth 2 -name '*.xcresult' -print -quit || true
)"

# Copy raw assets
[[ -f "${LOG_FILE}" ]] && cp "${LOG_FILE}" "${OUT_DIR}/xcodebuild.log" || true
if [[ -n "${XCBUNDLE}" ]]; then
  /usr/bin/xcrun xcresulttool get --path "${XCBUNDLE}" --format json > "${OUT_DIR}/xcresult.json" || true
fi

# Simple error harvest from the log
grep -inE '(^| )error:|Internal inconsistency error' "${LOG_FILE}" > "${OUT_DIR}/errors-from-log.txt" || true
tail -n 300 "${LOG_FILE}" > "${OUT_DIR}/xcodebuild.tail.txt" || true

# Try to summarize issues from xcresult (best-effort; requires jq)
if command -v jq >/dev/null 2>&1 && [[ -f "${OUT_DIR}/xcresult.json" ]]; then
  jq 'def v:$; {
        topLevelKeys: (keys),
        containsActions: has("actions"),
        errors: .. | objects | select(has("errorSummaries")) | .errorSummaries? // [] ,
        warnings: .. | objects | select(has("warningSummaries")) | .warningSummaries? // []
      }' "${OUT_DIR}/xcresult.json" > "${OUT_DIR}/issues.json" || true
fi

# Human-friendly report
{
  echo "# iOS CI Report"
  echo
  echo "## Quick status"
  if [[ -s "${OUT_DIR}/errors-from-log.txt" ]]; then
    echo "- ❌ Errors detected in xcodebuild log"
  else
    echo "- ✅ No explicit 'error:' lines found in xcodebuild log"
  fi
  [[ -n "${XCBUNDLE}" ]] && echo "- xcresult: ${XCBUNDLE##*/}" || echo "- xcresult: (not found)"
  echo
  echo "## Top errors (from log)"
  if [[ -s "${OUT_DIR}/errors-from-log.txt" ]]; then
    head -n 25 "${OUT_DIR}/errors-from-log.txt"
  else
    echo "(none)"
  fi
  echo
  echo "## Tail of xcodebuild.log"
  sed 's/\x1b\[[0-9;]*m//g' "${OUT_DIR}/xcodebuild.tail.txt" 2>/dev/null || true
} > "${OUT_DIR}/report.md"

# Ultra-short Agent digest (keep small)
{
  echo "### iOS CI Agent Digest"
  echo "- Include only *actionable* items."
  echo "- Most recent errors (max 15):"
  if [[ -s "${OUT_DIR}/errors-from-log.txt" ]]; then
    head -n 15 "${OUT_DIR}/errors-from-log.txt"
  else
    echo "(none)"
  fi
} > "${OUT_DIR}/report_agent.md"

# Never fail CI because of this diagnostic step
exit 0

