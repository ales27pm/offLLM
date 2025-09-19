#!/usr/bin/env python3
import json, re, sys
from pathlib import Path

def main():
    pkg_path = Path("package.json")
    lock_path = Path("ios/Podfile.lock")

    if not pkg_path.exists() or not lock_path.exists():
        print("Missing package.json or ios/Podfile.lock", file=sys.stderr)
        sys.exit(2)

    pkg = json.loads(pkg_path.read_text())
    deps = {}
    deps.update(pkg.get("dependencies", {}))
    deps.update(pkg.get("devDependencies", {}))
    expected = deps.get("react-native")
    if not expected:
        print("No react-native in dependencies", file=sys.stderr)
        sys.exit(2)
    expected_version = expected.lstrip("^~")

    lock = lock_path.read_text()
    react_versions = set(re.findall(r"^\s+- React(?:-[^\s]+)? \((\d+(?:\.\d+){1,2})\)", lock, re.MULTILINE))
    hermes_versions = set(re.findall(r"^\s+- hermes-engine(?:/[^\s]+)? \((\d+(?:\.\d+){1,2})\)", lock, re.MULTILINE))

    print("react-native (package.json):", expected_version)
    print("React-* pods (Podfile.lock):", sorted(react_versions) or "NONE")
    print("hermes-engine pods (Podfile.lock):", sorted(hermes_versions) or "NONE")

    ok = react_versions == {expected_version} and hermes_versions == {expected_version}
    sys.exit(0 if ok else 2)

if __name__ == "__main__":
    main()
