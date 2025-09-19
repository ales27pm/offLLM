#!/usr/bin/env python3
"""Ensure React Native and Hermes pod versions match package.json."""
import json
import re
import sys
from pathlib import Path


def main() -> int:
    pkg_path = Path("package.json")
    lock_path = Path("ios/Podfile.lock")

    if not pkg_path.exists():
        print("package.json not found at repo root", file=sys.stderr)
        return 2
    if not lock_path.exists():
        print("ios/Podfile.lock not found (run pod install)", file=sys.stderr)
        return 2

    pkg = json.loads(pkg_path.read_text())
    deps = {}
    deps.update(pkg.get("dependencies", {}))
    deps.update(pkg.get("devDependencies", {}))
    expected = deps.get("react-native")
    if not expected:
        print("No react-native dependency in package.json", file=sys.stderr)
        return 2

    expected_version = expected.lstrip("^~")

    lock_data = lock_path.read_text()
    react_versions = set(
        re.findall(r"^\s+- React(?:-[^\s]+)? \((\d+(?:\.\d+){1,2})\)", lock_data, re.MULTILINE)
    )
    hermes_versions = set(
        re.findall(r"^\s+- hermes-engine(?:/[^\s]+)? \((\d+(?:\.\d+){1,2})\)", lock_data, re.MULTILINE)
    )

    print("react-native (package.json):", expected_version)
    print("React-* pods (Podfile.lock):", sorted(react_versions) or "NONE")
    print("hermes-engine pods (Podfile.lock):", sorted(hermes_versions) or "NONE")

    if react_versions == {expected_version} and hermes_versions == {expected_version}:
        return 0

    print(
        "\nMismatch detected. Run:\n"
        "  rm -rf ios/Pods ios/Podfile.lock\n"
        "  cd ios && pod repo update && pod install --repo-update\n",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
