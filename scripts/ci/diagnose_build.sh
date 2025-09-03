#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-build}"
REPORT_DIR="${BUILD_DIR}/ios-ci-report"
mkdir -p "${REPORT_DIR}"

LOG="${BUILD_DIR}/xcodebuild.log"
XCBUNDLE="${BUILD_DIR}/MyOfflineLLMApp.xcresult"

# Agent-friendly digest
AGENT_MD="${REPORT_DIR}/report_agent.md"
{
  echo "# iOS CI Diagnosis"
  echo
  echo "## Most likely root cause"
  echo '```'
  awk '/Internal inconsistency error|PhaseScriptExecution failed|error: /{print}' "${LOG}" | head -n 30 || true
  echo '```'
  echo
  echo "## Top XCResult issues"
} > "${AGENT_MD}"

if [ -d "${XCBUNDLE}" ] || [ -f "${XCBUNDLE}" ]; then
  /usr/bin/xcrun xcresulttool get --format json --path "${XCBUNDLE}" > "${REPORT_DIR}/xcresult.json" || true
  {
    echo
    echo '```'
    /usr/bin/grep -Eo '"issueType" *: *"[^"]+"|"title" *: *"[^"]+"' "${REPORT_DIR}/xcresult.json" \
      | sed -E 's/^"issueType": //g; s/^"title": //g; s/"//g' \
      | head -n 50 || true
    echo '```'
  } >> "${AGENT_MD}"
else
  echo "_No .xcresult found_" >> "${AGENT_MD}"
fi

# Human-readable report
{
  echo "# iOS CI Diagnosis (human)"
  echo
  echo "## Log: First errors"
  grep -nE "Internal inconsistency error|PhaseScriptExecution failed|error:" "${LOG}" | head -n 100 || true
  echo
  echo "## Log: Last 200 lines"
  tail -n 200 "${LOG}" || true
} > "${REPORT_DIR}/report.md"

# Copy raw log for convenience
cp -f "${LOG}" "${REPORT_DIR}/" || true

exit 0
