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

  const records = getValues(root, "actions").flatMap((action) =>
    getValues(action, "actionResult", "issues", "issueSummaries"),
  );

  const issues = records.map((rec) => ({
    type: rec.issueType?._value,
    title: rec.message?.text?._value,
    severity: rec.severity?._value,
    detailed: rec.producingTarget?.targetName?._value,
  }));

  return {
    ok: true,
    path: path.resolve(xcresultPath),
    issues,
  };
}
