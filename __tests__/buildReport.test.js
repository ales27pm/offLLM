const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const SCRIPT_PATH = path.join(
  __dirname,
  "..",
  "scripts",
  "ci",
  "build_report.py",
);

describe("build_report.py", () => {
  const tempDirs = [];

  afterEach(() => {
    while (tempDirs.length) {
      const dir = tempDirs.pop();
      try {
        fs.rmSync(dir, { recursive: true, force: true });
      } catch {
        // best effort cleanup
      }
    }
  });

  const createTempDir = (prefix) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
    tempDirs.push(dir);
    return dir;
  };

  const writeExecutable = (filePath, contents) => {
    fs.writeFileSync(filePath, contents);
    fs.chmodSync(filePath, 0o755);
  };

  const runScript = ({
    logContent = "",
    xcresultContent = "{}",
    stubScript,
  }) => {
    const tmp = createTempDir("build-report");
    const binDir = path.join(tmp, "bin");
    fs.mkdirSync(binDir);
    const stubPath = path.join(binDir, "xcrun");
    writeExecutable(stubPath, stubScript);

    const logPath = path.join(tmp, "xcodebuild.log");
    fs.writeFileSync(logPath, logContent, "utf8");

    const xcresultPath = path.join(tmp, "monGARS.xcresult");
    fs.writeFileSync(xcresultPath, xcresultContent, "utf8");

    const reportPath = path.join(tmp, "REPORT.md");
    const agentPath = path.join(tmp, "report_agent.md");

    const env = {
      ...process.env,
      PATH: `${binDir}${path.delimiter}${process.env.PATH || ""}`,
      PYTHONUTF8: "1",
    };

    const result = spawnSync(
      "python3",
      [
        SCRIPT_PATH,
        "--log",
        logPath,
        "--xcresult",
        xcresultPath,
        "--out",
        reportPath,
        "--agent",
        agentPath,
      ],
      {
        cwd: path.join(__dirname, ".."),
        env,
        encoding: "utf8",
      },
    );

    return {
      result,
      reportPath,
      agentPath,
      logPath,
      xcresultPath,
    };
  };

  test("summarizes log diagnostics and xcresult issues when legacy flag is supported", () => {
    const stubScript = `#!/usr/bin/env bash
set -euo pipefail

if [[ "\${2:-}" == "get" && "\${3:-}" == "--help" ]]; then
  echo "usage: includes --legacy"
  exit 0
fi

if [[ "\${2:-}" == "get" ]]; then
  echo '{"_type":{"_name":"IssueSummary"},"issueType":"CodeSign failure detected"}'
  exit 0
fi

>&2 echo "unexpected invocation: $*"
exit 1
`;

    const { result, reportPath, agentPath } = runScript({
      logContent: "error: Provisioning failed\nwarning: Swift deprecated API\n",
      stubScript,
    });

    if (result.stderr) {
      // Aid debugging on CI by surfacing stderr output.
      console.error(result.stderr);
    }

    expect(result.status).toBe(0);
    expect(result.stdout).toContain("✅ Reports generated");

    const humanReport = fs.readFileSync(reportPath, "utf8");
    expect(humanReport).toContain("- Workflow log:");
    expect(humanReport).toContain("error: Provisioning failed");
    expect(humanReport).toContain("warning: Swift deprecated API");
    expect(humanReport).toContain("CodeSign failure detected");

    const agentReport = fs.readFileSync(agentPath, "utf8");
    expect(agentReport).toContain("errors_count=1");
    expect(agentReport).toContain("warnings_count=1");
    expect(agentReport).toContain("xcresult_issues_count=1");
    expect(agentReport).toContain(
      "first_xcresult_issue=CodeSign failure detected",
    );
  });

  test("falls back to non-legacy xcresulttool when legacy invocation fails", () => {
    const stubScript = `#!/usr/bin/env bash
set -euo pipefail

if [[ "\${2:-}" == "get" && "\${3:-}" == "--help" ]]; then
  echo "usage: includes --legacy"
  exit 0
fi

if [[ "\${2:-}" == "get" && "\${5:-}" == "--legacy" ]]; then
  echo "error: --legacy not supported" >&2
  exit 64
fi

if [[ "\${2:-}" == "get" ]]; then
  echo '{"_type":{"_name":"IssueSummary"},"issueType":"Simulator fallback succeeded"}'
  exit 0
fi

>&2 echo "unexpected invocation: $*"
exit 1
`;

    const { result, reportPath, agentPath } = runScript({
      logContent: "warning: Legacy flag removed\n",
      stubScript,
    });

    if (result.stderr) {
      console.error(result.stderr);
    }

    expect(result.status).toBe(0);
    expect(result.stdout).toContain("✅ Reports generated");

    const humanReport = fs.readFileSync(reportPath, "utf8");
    expect(humanReport).toContain("Simulator fallback succeeded");

    const agentReport = fs.readFileSync(agentPath, "utf8");
    expect(agentReport).toContain("xcresult_issues_count=1");
    expect(agentReport).toContain(
      "first_xcresult_issue=Simulator fallback succeeded",
    );
  });

  test("records parse failures when xcresulttool is unavailable", () => {
    const stubScript = `#!/usr/bin/env bash
set -euo pipefail

if [[ "\${2:-}" == "get" && "\${3:-}" == "--help" ]]; then
  echo "usage"
  exit 0
fi

if [[ "\${2:-}" == "get" && "\${5:-}" == "--legacy" ]]; then
  printf "fatal: legacy mode removed" >&2
  exit 1
fi

if [[ "\${2:-}" == "get" ]]; then
  printf "xcresulttool crashed" >&2
  exit 2
fi

>&2 echo "unexpected invocation: $*"
exit 1
`;

    const { result, reportPath, agentPath } = runScript({
      logContent: "",
      stubScript,
    });

    if (result.stderr) {
      console.error(result.stderr);
    }

    expect(result.status).toBe(0);
    expect(result.stdout).toContain("✅ Reports generated");

    const humanReport = fs.readFileSync(reportPath, "utf8");
    expect(humanReport).toContain(
      "(xcresult parse failed: xcresulttool crashed)",
    );

    const agentReport = fs.readFileSync(agentPath, "utf8");
    expect(agentReport).toContain("xcresult_issues_count=1");
    expect(agentReport).toContain(
      "first_xcresult_issue=(xcresult parse failed: xcresulttool crashed)",
    );
  });
});
