/* eslint-env node */
import path from "node:path";
import { readText, writeText } from "./util.mjs";
import console from "node:console";

export async function fixCmd(opts) {
  const report = readText(path.resolve(opts.report));
  const agent = readText(path.resolve(opts.agent));

  // Heuristic suggestions (no network calls). Expand as needed.
  const suggestions = [];

  if (/\[Hermes\] Replace Hermes/i.test(report)) {
    suggestions.push([
      "Scrub Hermes replacement scripts",
      "Ensure both post_install and post_integrate remove any Hermes 'Replace Hermes' scripts in Pods and user targets. CI should grep failing phases and exit with error if present.",
    ]);
  }
  if (/Internal inconsistency error/i.test(report)) {
    suggestions.push([
      "Resolve internal inconsistency",
      "Clear SPM cache: `rm -rf ~/Library/Developer/Xcode/DerivedData/*` & `xcodebuild -resolvePackageDependencies`. Pin swift-transformers/MLX packages to versions verified with Xcode 16.x.",
    ]);
  }
  if (/deployment target .*9\.0/i.test(report)) {
    suggestions.push([
      "Bump deployment target for old pods",
      "In Podfile post_install, set `IPHONEOS_DEPLOYMENT_TARGET = '12.0'` for offending pods (e.g., RNDeviceInfo-RNDeviceInfoPrivacyInfo).",
    ]);
  }
  if (/PhaseScriptExecution failed/i.test(report)) {
    suggestions.push([
      "Harden [CP] phases",
      "Disable I/O file lists and set `ENABLE_USER_SCRIPT_SANDBOXING=NO` for Pods and user targets in post_install; also mark [CP] phases `always_out_of_date` when I/O empty.",
    ]);
  }

  const header = [
    "# Suggested Fixes (Codex CLI)",
    "",
    "This file is generated from `REPORT.md` + `report_agent.md` heuristics.",
    "",
    "## Context (agent summary)",
    "",
    agent,
    "",
    "## Proposed changes",
    "",
  ].join("\n");

  const body = suggestions.length
    ? suggestions.map(([t, d], i) => `### ${i + 1}. ${t}\n${d}\n`).join("\n")
    : "_No specific suggestions inferred from report content._\n";

  writeText(path.join(opts.out || "reports", "patches.md"), header + body);
  console.log("Generated reports/patches.md");
}
