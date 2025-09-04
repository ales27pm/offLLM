import path from "node:path";
import { fileURLToPath } from "node:url";
import { sh, getValues } from "./util.mjs";

export function parseXCResult(xcresultPath) {
  // Use xcrun xcresulttool if available (macOS runners have it)
  // Note: Xcode 16+ requires the --legacy flag to access result data from the 'get' command.
  // This was identified as a cause of failure from the provided report.json.
  const { code, stdout, stderr } = sh("xcrun", [
    "xcresulttool",
    "get",
    "--format",
    "json",
    "--legacy",
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

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const target =
    process.argv[2] || path.join("build", "MyOfflineLLMApp.xcresult");
  const res = parseXCResult(target);
  if (!res.ok) {
    console.error(JSON.stringify(res, null, 2));
    process.exit(1);
  }
  console.log(JSON.stringify(res, null, 2));
}
