#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-build}"
REPORT="${BUILD_DIR}/ci_diagnosis.md"
XCRESULT="${BUILD_DIR}/MyOfflineLLMApp.xcresult"
LOG="${BUILD_DIR}/xcodebuild.log"

mkdir -p "${BUILD_DIR}"
echo "# Build Diagnosis (compact)" > "${REPORT}"
echo "" >> "${REPORT}"

# Extract issues from .xcresult (if present) into markdown (uses Node from setup-node step)
if [ -d "${XCRESULT}" ] || [ -f "${XCRESULT}" ]; then
  JSON="${BUILD_DIR}/xcresult.json"
  # note: may fail on older Xcode; continue
  xcrun xcresulttool get --path "${XCRESULT}" --format json > "${JSON}" || true
  node - <<'NODE' "${JSON}" "${BUILD_DIR}/xcresult.md" || true
  const fs = require('fs');
  const input = process.argv[2], out = process.argv[3];
  try {
    const j = JSON.parse(fs.readFileSync(input,'utf8'));
    const val = x => (x && x._value) || (typeof x === 'string' ? x : '');
    const arr = x => (x && x._values) || [];
    const actions = arr(j.actions);
    const issues = actions.flatMap(a => arr(a.actionResult && a.actionResult.issues));
    const errors  = issues.flatMap(i => arr(i.errorSummaries)).map(e => ({msg: val(e.message), url: val(e.documentationURL)}));
    const warns   = issues.flatMap(i => arr(i.warningSummaries)).map(w => val(w.message));

    function uniq(xs){ return [...new Set(xs.filter(Boolean))]; }

    let md = "## xcresult errors\n";
    uniq(errors.map(e => `- ${e.msg}`)).slice(0, 50).forEach(line => md += line + "\n");
    md += "\n## xcresult warnings\n";
    uniq(warns.map(w => `- ${w}`)).slice(0, 50).forEach(line => md += line + "\n");
    fs.writeFileSync(out, md);
  } catch (e) {
    // ignore parse errors, keep report generation going
  }
NODE
  if [ -f "${BUILD_DIR}/xcresult.md" ]; then
    echo "## xcresult summary" >> "${REPORT}"
    cat "${BUILD_DIR}/xcresult.md" >> "${REPORT}"
    echo "" >> "${REPORT}"
  fi
fi

# Pull out error snippets from the xcodebuild log (3 lines of context, strip ANSI)
if [ -f "${LOG}" ]; then
  echo "## xcodebuild.log errors (with context)" >> "${REPORT}"
  python3 - "${LOG}" >> "${REPORT}" <<'PY' || true
import re, sys
log = sys.argv[1]
try:
    with open(log, 'r', errors='ignore') as f:
        lines = f.readlines()
    pattern = re.compile(r'error:|fatal error:|Command PhaseScriptExecution failed|Internal inconsistency error|never received target ended message', re.IGNORECASE)
    for idx, line in enumerate(lines):
        if pattern.search(line):
            print("```")
            for ctx in lines[max(0, idx-3): min(len(lines), idx+4)]:
                if '/clang' in ctx:
                    continue
                ctx = re.sub(r'\x1B\[[0-9;]*[A-Za-z]', '', ctx.rstrip("\n"))
                if len(ctx) > 500:
                    ctx = ctx[:500] + '…'
                print(ctx)
            print("```\n")
except Exception:
    pass
PY
fi

# Cap size to ~180KB so the AGENT can ingest it in one go
python3 - "$REPORT" <<'PY' || true
import sys, os
p=sys.argv[1]
if os.path.exists(p) and os.path.getsize(p)>180*1024:
    with open(p,'rb') as f: data=f.read(180*1024)
    with open(p,'wb') as f: f.write(data+b"\n\n[truncated]")
PY

echo "✅ Wrote ${REPORT}"
