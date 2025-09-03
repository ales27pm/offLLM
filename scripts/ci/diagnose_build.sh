#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-build}"
XC="${BUILD_DIR}/MyOfflineLLMApp.xcresult"
LOG="${BUILD_DIR}/xcodebuild.log"
OUT_MD="${BUILD_DIR}/ci_diagnosis.md"

shorten () {  # keep output tight for agents
  local max=${1:-8000}
  python3 - "$max" << 'PY'
import sys, textwrap
limit=int(sys.argv[1]); data=sys.stdin.read()
print((data if len(data)<=limit else data[:limit-200]+"\n\n…(truncated)…"))
PY
}

{
  echo "# iOS CI Diagnosis"
  echo
  echo "## Most likely root cause"
  # Heuristic: pick 5 most frequent / representative error lines
  if [ -f "$LOG" ]; then
    echo '```'
    ERR_LINES=$(grep -E '(^|: )error:|Internal inconsistency error' -n "$LOG" || true)
    if [ -n "$ERR_LINES" ]; then
      printf '%s\n' "$ERR_LINES" \
        | sed 's#^.*Build/Intermediates[^:]*:##' \
        | sed 's#^.*node_modules/[^:]*:##' \
        | cut -c -240 \
        | sort | uniq -c | sort -nr | head -n 5
    else
      echo "(no errors found)"
    fi
    echo '```'
  else
    echo "_log not found_"
  fi
  echo
  echo "## Top XCResult issues"
  if [ -d "$XC" ] || [ -f "$XC" ]; then
    (python3 scripts/xcresult_top_issues.py "$XC" 2>/dev/null | shorten 4000) || echo "_xcresult parse failed_"
  else
    echo "_xcresult missing_"
  fi
  echo
  echo "## Pointers"
  echo "- Full log: \`$LOG\`"
  echo "- Result bundle: \`$XC\`"
} > "$OUT_MD"

echo "Wrote $OUT_MD"
exit 0
