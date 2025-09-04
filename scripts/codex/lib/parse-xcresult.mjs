import path from "node:path";
import { sh, getValues } from "./util.mjs";

export function parseXCResult(xcresultPath) {
  // Use xcrun xcresulttool if available (macOS runners have it)
  const { code, stdout, stderr } = sh("xcrun", [
    "xcresulttool",
    "get",
    "--format",
    "json",
    "--path",
    xcresultPath,
  ]);

  if (code !== 0) {
    return {
      ok: false,
      error: "xcresulttool failed",
      stderr,
      path: xcresultPath,
    };
  }

  let root;
  try {
    root = JSON.parse(stdout);
  } catch (e) {
    return {
      ok: false,
      error: "xcresulttool JSON parse failed",
      stderr: e.message,
      path: xcresultPath,
    };
  }

  const records = getValues(root, "actions").flatMap((action) => [
    ...getValues(action, "actionResult", "issues", "issueSummaries").map(
      (rec) => ({ sourceType: "issueSummary", rec }),
    ),
    ...getValues(action, "actionResult", "issues", "testFailureSummaries").map(
      (rec) => ({ sourceType: "testFailure", rec }),
    ),
  ]);

  const { issues, errorCount, warningCount } = records.reduce(
    (acc, { sourceType, rec }) => {
      const issue = {
        type: rec.issueType?._value,
        title: rec.message?.text?._value,
        severity: rec.severity?._value,
        detailed: rec.producingTarget?.targetName?._value,
        sourceType,
      };

      const doc = rec.documentLocationInCreatingWorkspace;
      const url = doc?.url?._value;
      if (url) {
        issue.url = url;
        const loc = doc.concreteLocation;
        if (loc) {
          issue.filePath = loc.filePath?._value;
          const line = loc.lineNumber?._value;
          if (line && !isNaN(Number(line))) {
            issue.line = Number(line);
          }
        }
      }

      if (issue.severity === "error") acc.errorCount++;
      else if (issue.severity === "warning") acc.warningCount++;

      acc.issues.push(issue);
      return acc;
    },
    { issues: [], errorCount: 0, warningCount: 0 },
  );

  return {
    ok: true,
    path: path.resolve(xcresultPath),
    issues,
    errorCount,
    warningCount,
  };
}
