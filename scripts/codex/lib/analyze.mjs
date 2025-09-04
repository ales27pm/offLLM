/* eslint-env node */
import path from "node:path";
import { ensureDir, writeJSON, writeText } from "./util.mjs";
import { parseXcodebuildLog } from "./parse-xcodebuild.mjs";
import { parseXCResult } from "./parse-xcresult.mjs";
import { renderHumanReport } from "./render-report.mjs";
import { renderAgentReport } from "./render-agent-report.mjs";
import console from "node:console";

export async function analyzeCmd(opts) {
  const outDir = path.resolve(opts.out || "reports");
  ensureDir(outDir);

  const xcodebuild = parseXcodebuildLog(path.resolve(opts.log));
  const xcresult = parseXCResult(path.resolve(opts.xcresult));

  writeJSON(path.join(outDir, "report.json"), { xcodebuild, xcresult });
  writeText(
    path.join(outDir, "REPORT.md"),
    renderHumanReport({ xcodebuild, xcresult }),
  );
  writeText(
    path.join(outDir, "report_agent.md"),
    renderAgentReport({ xcodebuild, xcresult }),
  );

  // keep a tiny status file for CI grep
  const status = xcodebuild.errorCount > 0 ? "errors" : "ok";
  writeText(path.join(outDir, "status.txt"), status);

  console.log(`Wrote reports to: ${outDir}`);
}
