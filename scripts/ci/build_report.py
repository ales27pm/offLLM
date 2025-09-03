#!/usr/bin/env python3
"""
Generates REPORT.md (human) and report_agent.md (LLM-friendly) from:
- build/MyOfflineLLMApp.xcresult (if present)
- build/xcodebuild.log (if present)

Safe-by-default: never exits non-zero; won't break CI.
"""

import json, os, re, sys, subprocess
from pathlib import Path

BUILD_DIR = Path(os.environ.get("BUILD_DIR", "build"))
XCRESULT = BUILD_DIR / "MyOfflineLLMApp.xcresult"
LOGFILE  = BUILD_DIR / "xcodebuild.log"
OUT_HUMAN = Path("REPORT.md")
OUT_AGENT = Path("report_agent.md")
XCRESULT_JSON = BUILD_DIR / "xcresult.json"

def sh(cmd):
    try:
        return subprocess.check_output(cmd, text=True).strip()
    except Exception:
        return ""

def try_dump_xcresult_json():
    if XCRESULT.is_dir():
        try:
            data = sh(["xcrun", "xcresulttool", "get", "--format", "json", "--path", str(XCRESULT)])
            if data:
                XCRESULT_JSON.write_text(data)
        except Exception:
            pass

def collect_xcresult_messages():
    """Return list of (severity, title/message, path?)."""
    if not XCRESULT_JSON.exists():
        return []
    try:
        data = json.loads(XCRESULT_JSON.read_text())
    except Exception:
        return []
    out = []
    def walk(o):
        if isinstance(o, dict):
            title = o.get("title") or o.get("message")
            sev = o.get("severity") or o.get("_severity") or ""
            loc = o.get("location")
            path = None
            if isinstance(loc, dict):
                path = loc.get("path")
            if isinstance(title, str) and title.strip():
                out.append((sev, title.strip(), path))
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(data)
    seen, dedup = set(), []
    for tup in out:
        if tup not in seen:
            seen.add(tup)
            dedup.append(tup)
    return dedup

def grep_lines(path: Path, pattern: str, max_lines: int):
    if not path.exists():
        return []
    try:
        rx = re.compile(pattern, re.IGNORECASE)
        res = []
        with path.open(errors="ignore") as f:
            for line in f:
                if rx.search(line):
                    res.append(line.rstrip())
        return res[-max_lines:]
    except Exception:
        return []

def detect_root_cause(log_lines):
    root = None
    joined = "\n".join(log_lines)
    if re.search(r"Internal inconsistency error: never received target ended message", joined, re.I):
        root = "Xcode internal scheduler inconsistency (e.g., TensorUtils target) — often triggered by flaky/expensive script phases or huge graphs."
    if re.search(r"\[Hermes\]\s*Replace Hermes", joined, re.I):
        root = "Leftover Hermes 'Replace Hermes' script phase present (should be scrubbed)."
    return root or "Undetermined"

def write_human_report(xc_msgs, log_errors, log_warns):
    with OUT_HUMAN.open("w") as w:
        w.write("# iOS CI Diagnosis\n\n")
        w.write("## Inputs\n")
        w.write(f"- Log: `{LOGFILE}`\n")
        w.write(f"- XCResult: `{XCRESULT}`\n\n")
        w.write("## Top XCResult issues\n")
        if xc_msgs:
            for sev, title, path in xc_msgs[:120]:
                tag = sev.upper() if sev else "ISSUE"
                loc = f" — {path}" if path else ""
                w.write(f"- **{tag}**: {title}{loc}\n")
        else:
            w.write("_No xcresult messages extracted._\n")
        w.write("\n")
        w.write("## Log highlights\n\n")
        if LOGFILE.exists():
            w.write("### Errors\n")
            if log_errors:
                w.write("\n".join(log_errors) + "\n\n")
            else:
                w.write("_No 'error' lines captured._\n\n")
            w.write("### Suspicious warnings (sample)\n")
            if log_warns:
                w.write("\n".join(log_warns) + "\n")
            else:
                w.write("_No suspicious warnings captured._\n")
        else:
            w.write("_No xcodebuild.log found_\n")

def write_agent_report(xc_msgs, log_errors):
    root = detect_root_cause(log_errors)
    with OUT_AGENT.open("w") as w:
        w.write("# iOS CI Agent Report\n\n")
        w.write("## Most likely root cause\n")
        w.write(f"`{root}`\n\n")
        w.write("## Top issues (dedup, capped)\n")
        if xc_msgs:
            for sev, title, path in xc_msgs[:60]:
                tag = sev.upper() if sev else "ISSUE"
                loc = f" @ {path}" if path else ""
                w.write(f"- {tag}: {title}{loc}\n")
        else:
            w.write("- (no xcresult)\n")
        w.write("\n## Pointers\n")
        w.write(f"- Log: `{LOGFILE}`\n")
        w.write(f"- Result bundle: `{XCRESULT}`\n")

def main():
    try_dump_xcresult_json()
    xc_msgs   = collect_xcresult_messages()
    log_errs  = grep_lines(LOGFILE, r"(error:|Command PhaseScriptExecution failed)", 160)
    log_warns = grep_lines(LOGFILE, r"(Run script build phase .* will be run during every build|deployment target)", 120)
    write_human_report(xc_msgs, log_errs, log_warns)
    write_agent_report(xc_msgs, log_errs)

if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
