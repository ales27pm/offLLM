import path from "node:path";
import { sh } from "./util.mjs";

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

  // Very large; we only extract key items to keep memory small
  const root = JSON.parse(stdout);
  const issues = [];

  try {
    const actions = root.actions?._values ?? [];
    for (const action of actions) {
      const records =
        action.actionResult?.issues?.issueSummaries?._values ?? [];
      for (const rec of records) {
        issues.push({
          type: rec.issueType?._value,
          title: rec.message?.text?._value,
          severity: rec.severity?._value,
          detailed: rec?.producingTarget?.targetName?._value,
        });
      }
    }
  } catch {
    // ignore parse errors; we still return root status
  }

  return {
    ok: true,
    path: path.resolve(xcresultPath),
    issues,
  };
}
