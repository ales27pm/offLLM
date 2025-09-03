#!/usr/bin/env bash
# scripts/ci/diagnose_build.sh
# Produces:
#   build/ios-ci-report/
#     ├─ REPORT.md              # human-readable, full detail
#     ├─ report_agent.md        # compact digest (safe for agents)
#     ├─ xcodebuild.log         # copied from $BUILD_DIR
#     └─ xcresult.json          # parsed xcresult (if present)
#
# This script must never fail CI. It will exit 0 even if parsing fails.

set -Eeuo pipefail

# --------- Inputs & setup ----------
BUILD_DIR="${1:-build}"
OUT_DIR="${BUILD_DIR}/ios-ci-report"
LOG_PATH="${BUILD_DIR}/xcodebuild.log"
XCRESULT_DIR_DEFAULT="${BUILD_DIR}/MyOfflineLLMApp.xcresult"
XCRESULT_DIR="${XCRESULT_PATH:-$XCRESULT_DIR_DEFAULT}"

mkdir -p "${OUT_DIR}"

# Always copy the log if present
if [[ -f "${LOG_PATH}" ]]; then
  cp "${LOG_PATH}" "${OUT_DIR}/xcodebuild.log"
fi

# --------- Helpers ----------
has_line() {
  local needle="$1"
  if [[ -f "${LOG_PATH}" ]]; then
    /usr/bin/grep -Fq "${needle}" "${LOG_PATH}" || return 1
  else
    return 1
  fi
}

safe_grep() {
  local pattern="$1"
  if [[ -f "${LOG_PATH}" ]]; then
    /usr/bin/grep -E "${pattern}" "${LOG_PATH}" || true
  fi
}

truncate_chars() {
  # truncates stdin to N chars (default 25000)
  local limit="${1:-25000}"
  python3 - "$limit" <<'PY2'
import sys, textwrap, json
limit = int(sys.argv[1])
data = sys.stdin.read()
if len(data) <= limit:
    sys.stdout.write(data)
else:
    sys.stdout.write(data[:limit] + "\n\n[...truncated...]\n")
PY2
}

json_escape() {
  # escape for JSON/Markdown code fences if needed
  python3 - <<'PY3'
import sys, json
print(json.dumps(sys.stdin.read())[1:-1])
PY3
}

# --------- Parse xcresult (best-effort) ----------
XCRESULT_JSON="${OUT_DIR}/xcresult.json"
rm -f "${XCRESULT_JSON}" "${XCRESULT_JSON}.tmp" 2>/dev/null || true
if [[ -d "${XCRESULT_DIR}" ]]; then
  # xcrun must succeed; otherwise leave empty JSON
  if /usr/bin/xcrun xcresulttool get --format json --path "${XCRESULT_DIR}" > "${XCRESULT_JSON}.tmp" 2>/dev/null; then
    mv "${XCRESULT_JSON}.tmp" "${XCRESULT_JSON}"
  else
    echo "{}" > "${XCRESULT_JSON}" || true
  fi
else
  echo "{}" > "${XCRESULT_JSON}" || true
fi

# Extract a compact summary from the xcresult.json (best-effort)
XCRESULT_SUMMARY="$(python3 - <<'PY4'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
try:
    data = json.loads(p.read_text() or "{}")
except Exception:
    data = {}
# Rough scan for issues
def dig(obj, keys, default=None):
    cur = obj
    for k in keys:
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            return default
    return cur

def collect_issues(obj, acc):
    if isinstance(obj, dict):
        if '_type' in obj and 'name' in obj.get('_type', {}):
            tname = obj['_type']['name']
            if tname.endswith('IssueSummary'):
                title = obj.get('issueType', 'Issue')
                msg = obj.get('message', '')
                acc.append(f"{title}: {msg}")
        for v in obj.values():
            collect_issues(v, acc)
    elif isinstance(obj, list):
        for v in obj:
            collect_issues(v, acc)

issues=[]
collect_issues(data, issues)
print("\n".join(issues[:120]))  # cap
PY4
"${XCRESULT_JSON}")"

# --------- Mine the log for errors/warnings (best-effort) ----------
ERRORS="$(safe_grep '^error:| error:|Command PhaseScriptExecution failed with a nonzero exit code|Internal inconsistency error|never received target ended message')"
WARNINGS="$(safe_grep '^warning:| warning:|The iOS deployment target .* is set to 9.0|Replace Hermes')"

# High-signal heuristics
LIKELY_ROOT_CAUSE=""
if has_line "Internal inconsistency error: never received target ended message" || has_line "never received target ended message"; then
  LIKELY_ROOT_CAUSE=$'Xcode build system race on Swift target (seen as “never received target ended message”). Workaround: serialize builds (-parallelizeTargets NO -jobs 1).'
elif has_line "[CP-User] [Hermes] Replace Hermes" || has_line "Replace Hermes for the right configuration, if needed"; then
  LIKELY_ROOT_CAUSE=$'Residual Hermes “Replace Hermes” script phase. Ensure it is scrubbed in Podfile post_install/post_integrate and/or by CI step.'
elif has_line "Command PhaseScriptExecution failed with a nonzero exit code"; then
  LIKELY_ROOT_CAUSE=$'A CocoaPods [CP] / user script phase failed. Check preceding lines for the exact phase and fix its inputs/outputs or conditions.'
else
  LIKELY_ROOT_CAUSE=$'No single smoking gun found. See Top Issues sections below.'
fi

# --------- Build REPORT.md (full) ----------
REPORT_PATH="${OUT_DIR}/REPORT.md"
{
cat <<EOF
# iOS CI Build Diagnosis Report

## 1) Context
- **Workspace**: \`ios/MyOfflineLLMApp.xcworkspace\`
- **Scheme**: \`MyOfflineLLMApp\`
- **Build dir**: \`${BUILD_DIR}\`
- **Artifacts**:
  - \`${OUT_DIR}/xcodebuild.log\` (copy of CI log)
  - \`${OUT_DIR}/xcresult.json\` (parsed, if available)
  - \`${OUT_DIR}/report_agent.md\` (compact digest for agents)

---

## 2) Most likely root cause
\`\`\`
${LIKELY_ROOT_CAUSE}
\`\`\`

---

## 3) Top issues from xcodebuild.log
### Errors (first 200 lines matched)
\`\`\`
$(echo "${ERRORS}" | head -n 200)
\`\`\`

### Warnings (first 200 lines matched)
\`\`\`
$(echo "${WARNINGS}" | head -n 200)
\`\`\`

---

## 4) XCResult highlights (best-effort)
\`\`\`
${XCRESULT_SUMMARY}
\`\`\`

---

## 5) Recommendations

### A) Make build deterministic on CI
- Add flags to **all xcodebuild** invocations:
  - \`-parallelizeTargets NO -jobs 1\`  
  Rationale: mitigates intermittent “never received target ended message” on Swift packages.

### B) Keep Hermes script phases out
- Ensure Podfile \`post_install\` and \`post_integrate\` remove:
  - \`[CP-User] [Hermes] Replace Hermes for the right configuration, if needed\`
- Optionally run a CI ruby scrub after \`pod install\`.

### C) Clean noisy warnings
- Enforce \`IPHONEOS_DEPLOYMENT_TARGET = 18.0\` for pod targets in \`post_install\`.
- For "[Create Symlinks to Header Folders]" phases:
  - Add outputs or enable "Based on dependency analysis" to prevent the “run during every build” warning.

### D) Keep this diagnosis step non-blocking
- This script will **always exit 0**; do not fail CI on reporting.

---

## 6) Pointers
- Full log: \`${BUILD_DIR}/xcodebuild.log\`
- XCResult bundle: \`${BUILD_DIR}/MyOfflineLLMApp.xcresult\`
- Generated JSON: \`${OUT_DIR}/xcresult.json\`

EOF
} > "${REPORT_PATH}"

# --------- Build report_agent.md (compact; safe for prompt input) ----------
AGENT_PATH="${OUT_DIR}/report_agent.md"
{
cat <<'EOF'
# iOS CI Diagnosis (Agent Digest)

**Goal:** summarize only the highest-signal items for automated fixing.

## Most likely root cause
EOF
echo
echo "${LIKELY_ROOT_CAUSE}" | truncate_chars 800
echo
cat <<'EOF'

## High-signal errors (truncated)
EOF
echo
echo "${ERRORS}" | head -n 120 | truncate_chars 4000
echo
cat <<'EOF'

## High-signal warnings (truncated)
EOF
echo
echo "${WARNINGS}" | head -n 120 | truncate_chars 4000
echo
cat <<'EOF'

## Recommended actions (ordered)
1. Add `-parallelizeTargets NO -jobs 1` to all xcodebuild calls in CI.
2. Ensure Hermes "Replace Hermes" script phases are removed in Podfile hooks and by scrub step.
3. Force `IPHONEOS_DEPLOYMENT_TARGET = 18.0` for pods in `post_install`.
4. Silence "Create Symlinks to Header Folders" warnings by adding outputs or enabling dependency analysis.
EOF
} > "${AGENT_PATH}"

# --------- Also write a tiny step summary for GitHub UI ----------
{
  echo "### iOS CI Diagnosis"
  echo
  echo "**Most likely root cause:**"
  echo
  echo ">\`${LIKELY_ROOT_CAUSE}\`"
  echo
  echo "- Full report: \`${REPORT_PATH}\`"
  echo "- Agent digest: \`${AGENT_PATH}\`"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}" || true

# Never fail CI because of diagnosis
exit 0
