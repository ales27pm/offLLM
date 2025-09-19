#!/usr/bin/env python3
"""Fail if any Pods targets use a C++ standard other than c++20."""
from __future__ import annotations

import re
import sys
from pathlib import Path

PODS_PROJECT = Path("ios/Pods/Pods.xcodeproj/project.pbxproj")
APP_PROJECT = Path("ios/monGARS.xcodeproj/project.pbxproj")


def extract_standards(text: str) -> set[str]:
    pattern = re.compile(r"CLANG_CXX_LANGUAGE_STANDARD\s*=\s*([^;\n]+)")
    values: set[str] = set()
    for match in pattern.finditer(text):
        value = match.group(1).strip().strip('"')
        if value:
            values.add(value)
    return values


def main() -> int:
    if not PODS_PROJECT.exists():
        print("Pods.xcodeproj not found (run pod install)", file=sys.stderr)
        return 2

    pods_text = PODS_PROJECT.read_text(errors="ignore")
    pods_values = extract_standards(pods_text)
    print("Pods CLANG_CXX_LANGUAGE_STANDARD values:", pods_values or {"(none)"})

    effective_pods_values = {value for value in pods_values if not value.startswith("$(")}
    pods_ok = (effective_pods_values == {"c++20"})

    if APP_PROJECT.exists():
        app_text = APP_PROJECT.read_text(errors="ignore")
        app_values = extract_standards(app_text)
        print("App CLANG_CXX_LANGUAGE_STANDARD values:", app_values or {"(none)"})
    else:
        print("App project not found at", APP_PROJECT, "(skipping app check)")

    return 0 if pods_ok else 2


if __name__ == "__main__":
    sys.exit(main())
