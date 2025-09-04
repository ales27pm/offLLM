#!/usr/bin/env node
/* eslint-env node */
import { Command } from "commander";
import { analyzeCmd } from "./lib/analyze.mjs";
import { fixCmd } from "./lib/fix.mjs";
import process from "node:process";

const program = new Command();
program
  .name("codex")
  .description("Codex CLI subcommands for iOS diagnostics & autofix stubs")
  .version("1.0.0");

program
  .command("analyze")
  .requiredOption("--log <path>", "Path to xcodebuild.log")
  .requiredOption("--xcresult <path>", "Path to .xcresult bundle")
  .option("--out <dir>", "Output directory", "reports")
  .description("Analyze logs & xcresult to produce reports")
  .action(analyzeCmd);

program
  .command("fix")
  .requiredOption("--report <path>", "Path to REPORT.md")
  .requiredOption("--agent <path>", "Path to report_agent.md")
  .option("--out <dir>", "Output directory", "reports")
  .description("Read reports and produce patch suggestions (no network)")
  .action(fixCmd);

program.parseAsync(process.argv);
