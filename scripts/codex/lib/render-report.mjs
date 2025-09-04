export function renderHumanReport({ xcodebuild, xcresult }) {
  const lines = [];

  lines.push("# iOS CI Diagnosis");
  lines.push("");
  lines.push("## Most likely root cause");
  lines.push("```\n" + guessRootCause(xcodebuild, xcresult) + "\n```");
  lines.push("");
  lines.push("## Top XCResult issues");
  if (xcresult?.ok && xcresult.issues?.length) {
    for (const i of xcresult.issues.slice(0, 15)) {
      lines.push(
        `- **${i.severity ?? "unknown"}**: ${i.title ?? "(no title)"} ${i.detailed ? `— _${i.detailed}_` : ""}`,
      );
    }
  } else {
    lines.push("- (no structured issues captured from xcresulttool)");
  }
  lines.push("");
  lines.push("## Log stats");
  lines.push(`- Errors: **${xcodebuild.errorCount}**`);
  lines.push(`- Warnings: **${xcodebuild.warningCount}**`);
  if (xcodebuild.hermesScripts.length)
    lines.push(`- Hermes script mentions: ${xcodebuild.hermesScripts.length}`);
  if (xcodebuild.phaseScriptFailures.length)
    lines.push(
      `- PhaseScriptExecution failures: ${xcodebuild.phaseScriptFailures.length}`,
    );
  if (xcodebuild.deploymentTargetNotes.length)
    lines.push(
      `- Deployment target mismatches: ${xcodebuild.deploymentTargetNotes.length}`,
    );
  if (xcodebuild.internalInconsistency.length)
    lines.push(
      `- Internal inconsistency errors: ${xcodebuild.internalInconsistency.length}`,
    );
  lines.push("");

  lines.push("## Pointers");
  lines.push(`- Full log: \`${xcodebuild.logPath}\``);
  lines.push(`- Result bundle: \`${xcresult?.path ?? "(unavailable)"}\``);

  return lines.join("\n");
}

function guessRootCause(x, r) {
  if (x.hermesScripts.length) {
    return "Hermes '[CP-User] Replace Hermes...' script phase is still present; scrub it post-install/post-integrate.";
  }
  if (x.internalInconsistency.length) {
    return "Xcode 'Internal inconsistency error' (e.g., swift-transformers/TensorUtils). Clean SPM caches & ensure packages resolve.";
  }
  if (x.phaseScriptFailures.length) {
    return "A CocoaPods '[CP]' script phase failed; check inputs/outputs or sandboxing settings.";
  }
  if (x.deploymentTargetNotes.length) {
    return "One or more Pods declare iOS 9.0; raise to 12+ or set `IPHONEOS_DEPLOYMENT_TARGET` via post_install overrides.";
  }
  if (x.errorCount > 0) {
    return "Build contains errors in xcodebuild.log; see the Errors section for specifics.";
  }
  if (r?.ok && r.issues?.length) {
    return `XCResult lists ${r.issues.length} issue(s); inspect the highest severity above.`;
  }
  return "No obvious single root cause detected; inspect warnings and CI environment.";
}
