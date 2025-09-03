#!/usr/bin/env python3
"""Generate CI build reports from xcodebuild log and xcresult.

Creates two files:
  - REPORT.md       (human-readable)
  - report_agent.md (compact key=value digest for agents)

The script never exits non-zero, so it cannot break CI.
"""

import argparse
import json
import os
import subprocess
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser(description="Generate CI build reports")
    p.add_argument("--log", required=True, help="Path to xcodebuild.log")
    p.add_argument("--xcresult", required=True, help="Path to .xcresult bundle")
    p.add_argument("--out", default="REPORT.md", help="Output human report path")
    p.add_argument("--agent", default="report_agent.md", help="Output agent report path")
    return p.parse_args()


def parse_log(path: Path):
    errors, warnings = [], []
    try:
        with path.open(errors="ignore") as f:
            for line in f:
                low = line.lower().strip()
                if "error:" in low:
                    errors.append(line.strip())
                elif "warning:" in low:
                    warnings.append(line.strip())
    except FileNotFoundError:
        pass
    return errors, warnings


def parse_xcresult(path: Path):
    if not path.exists():
        return []
    try:
        out = subprocess.check_output(
            ["xcrun", "xcresulttool", "get", "--format", "json", "--path", str(path)],
            text=True,
        )
        data = json.loads(out)
    except Exception as e:  # xcresulttool missing or parse error
        return [f"(xcresult parse failed: {e})"]

    issues = []

    def walk(obj):
        if isinstance(obj, dict):
            t = obj.get("_type", {}).get("_name", "")
            if "Issue" in t:
                desc = obj.get("issueType") or obj.get("title") or obj.get("message")
                if isinstance(desc, str) and desc:
                    issues.append(desc)
            for v in obj.values():
                walk(v)
        elif isinstance(obj, list):
            for v in obj:
                walk(v)

    walk(data)
    return issues


def write_human_report(out_path: Path, log_path: Path, xc_path: Path, errors, warnings, xc_issues):
    with out_path.open("w") as f:
        f.write("# iOS CI Report\n\n")
        f.write(f"- Workflow log: {log_path}\n")
        f.write(f"- Result bundle: {xc_path}\n\n")

        f.write("## Errors\n")
        if errors:
            f.write("\n".join(f"- {e}" for e in errors[:100]))
            if len(errors) > 100:
                f.write(f"\n... ({len(errors)-100} more)\n")
        else:
            f.write("No errors detected\n")

        f.write("\n\n## Warnings\n")
        if warnings:
            f.write("\n".join(f"- {w}" for w in warnings[:100]))
            if len(warnings) > 100:
                f.write(f"\n... ({len(warnings)-100} more)\n")
        else:
            f.write("No warnings detected\n")

        f.write("\n\n## XCResult Issues\n")
        if xc_issues:
            f.write("\n".join(f"- {i}" for i in xc_issues[:50]))
            if len(xc_issues) > 50:
                f.write(f"\n... ({len(xc_issues)-50} more)\n")
        else:
            f.write("No issues detected\n")


def write_agent_report(out_path: Path, errors, warnings, xc_issues):
    with out_path.open("w") as f:
        f.write("# agent_report\n")
        f.write(f"errors_count={len(errors)}\n")
        f.write(f"warnings_count={len(warnings)}\n")
        f.write(f"xcresult_issues_count={len(xc_issues)}\n")
        if errors:
            f.write("first_error=" + errors[0].replace("|", "/") + "\n")
        if warnings:
            f.write("first_warning=" + warnings[0].replace("|", "/") + "\n")
        if xc_issues:
            f.write("first_xcresult_issue=" + xc_issues[0].replace("|", "/") + "\n")


def main():
    args = parse_args()
    log_path = Path(args.log)
    xc_path = Path(args.xcresult)

    errors, warnings = parse_log(log_path)
    xc_issues = parse_xcresult(xc_path)

    write_human_report(Path(args.out), log_path, xc_path, errors, warnings, xc_issues)
    write_agent_report(Path(args.agent), errors, warnings, xc_issues)
    print(f"✅ Reports generated: {args.out}, {args.agent}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"⚠️ Report generation failed: {exc}")
        # never fail CI
