#!/usr/bin/env bash
set -euo pipefail

echo "▶️  Unsigned iOS build starting…"
ROOT="$(pwd)"
IOS_DIR="ios"
DERIVED="build"

# Inputs (optional overrides via env)
: "${SCHEME:=}"                                # if empty, we'll auto-detect
: "${WORKSPACE:=}"                             # optional pre-known workspace path
: "${IPA_OUTPUT:=${ROOT}/offLLM-unsigned.ipa}" # default artifact path

echo "Environment:"
echo "  SCHEME=${SCHEME:-<auto>}"
echo "  WORKSPACE=${WORKSPACE:-<auto>}"
echo "  IPA_OUTPUT=${IPA_OUTPUT}"
echo

# --- 0) Ensure tools we need are present ---
if ! command -v xcpretty >/dev/null 2>&1; then
  gem install xcpretty -N || true
fi
if ! command -v pod >/dev/null 2>&1; then
  gem install cocoapods -N
fi

# --- 1) XcodeGen (only if a spec exists) ---
# Look for an XcodeGen spec at ios/project.yml or project.yml
SPEC=""
if [[ -f "${IOS_DIR}/project.yml" ]]; then
  SPEC="${IOS_DIR}/project.yml"
elif [[ -f "project.yml" ]]; then
  SPEC="project.yml"
fi

if [[ -n "${SPEC}" ]]; then
  echo "Generating Xcode project with XcodeGen using spec: ${SPEC}"
  # install via Homebrew if missing
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Installing XcodeGen via Homebrew…"
    brew update
    brew install xcodegen
  fi
  pushd "$(dirname "${SPEC}")" >/dev/null
  xcodegen generate
  popd >/dev/null
else
  echo "No XcodeGen spec found — skipping generation."
fi

# --- 2) Locate Podfile, project, workspace ---
echo "Locating Podfile…"
PODFILE="$(git ls-files | grep -E '^ios(/.*)?/Podfile$' | head -n1 || true)"
if [[ -z "${PODFILE}" ]]; then
  echo "❌ No Podfile found under ios/. Aborting."
  exit 1
fi
PODDIR="$(dirname "${PODFILE}")"
echo "  Podfile: ${PODFILE}"

if [[ -z "${WORKSPACE}" ]]; then
  WORKSPACE="$(find "${PODDIR}" -maxdepth 4 -name '*.xcworkspace' | head -n1 || true)"
fi
XCPROJ="$(find "${PODDIR}" -maxdepth 4 -name '*.xcodeproj' | head -n1 || true)"

echo "Detected:"
echo "  Workspace: ${WORKSPACE:-<none>}"
echo "  Xcodeproj: ${XCPROJ:-<none>}"

if [[ -z "${WORKSPACE}" && -z "${XCPROJ}" ]]; then
  echo "❌ No .xcworkspace or .xcodeproj found under ${PODDIR}. Aborting."
  exit 1
fi

# --- 3) Patch Podfile 'project' line if it points to a wrong path ---
if [[ -n "${XCPROJ}" ]]; then
  echo "Normalising Podfile project path…"
  RELPROJ="$(python3 - <<'PY'
import os
poddir = os.environ["PODDIR"]
xcproj = os.environ["XCPROJ"]
print(os.path.relpath(xcproj, poddir))
PY
)"
  # macOS sed needs the empty '' argument after -i
  if grep -E "^\s*project\s+['\"][^'\"]+['\"]" "${PODFILE}" >/dev/null 2>&1; then
    sed -i '' -E "s|^\s*project\s+['\"][^'\"]+['\"]|project '${RELPROJ}'|g" "${PODFILE}"
    echo "  Podfile 'project' set to: ${RELPROJ}"
  else
    echo "  Podfile has no explicit 'project' line (auto-detect is fine)."
  fi
fi

# --- 4) Install Pods ---
echo "Running pod install…"
pushd "${PODDIR}" >/dev/null
pod repo update
pod install --verbose
popd >/dev/null

# --- 5) Detect scheme if not provided ---
if [[ -z "${SCHEME}" ]]; then
  echo "Detecting scheme…"
  if [[ -n "${WORKSPACE}" ]]; then
    LIST_JSON="$(xcodebuild -list -json -workspace "${WORKSPACE}" 2>/dev/null || true)"
  else
    LIST_JSON="$(xcodebuild -list -json -project "${XCPROJ}" 2>/dev/null || true)"
  fi

  SCHEME="$(python3 - <<'PY'
import json, os
data = os.environ.get("LIST_JSON","")
try:
    j=json.loads(data)
    for container in ("workspace","project"):
        if container in j and "schemes" in j[container] and j[container]["schemes"]:
            schemes=[s for s in j[container]["schemes"] if not s.startswith("Pods-")]
            print((schemes or j[container]["schemes"])[0])
            raise SystemExit
except Exception:
    pass
print("")
PY
)"
  if [[ -z "${SCHEME}" ]]; then
    if [[ -n "${XCPROJ}" ]]; then
      SCHEME="$(basename "${XCPROJ%.xcodeproj}")"
      echo "  Fallback scheme: ${SCHEME}"
    else
      echo "❌ Unable to determine a scheme. Aborting."
      exit 1
    fi
  else
    echo "  Scheme: ${SCHEME}"
  fi
fi

# --- 6) Clean build (unsigned) ---
echo "Building (unsigned)…"
if [[ -n "${WORKSPACE}" ]]; then
  xcodebuild \
    -workspace "${WORKSPACE}" \
    -scheme "${SCHEME}" \
    -sdk iphoneos \
    -configuration Release \
    -derivedDataPath "${DERIVED}" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY="" \
    clean build | xcpretty
else
  xcodebuild \
    -project "${XCPROJ}" \
    -scheme "${SCHEME}" \
    -sdk iphoneos \
    -configuration Release \
    -derivedDataPath "${DERIVED}" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY="" \
    clean build | xcpretty
fi

# --- 7) Package unsigned IPA ---
echo "Packaging unsigned IPA…"
APP_PATH="$(find "${DERIVED}/Build/Products/Release-iphoneos" -maxdepth 1 -name '*.app' | head -n1 || true)"
if [[ -z "${APP_PATH}" ]]; then
  echo "❌ No .app produced. Aborting."
  exit 1
fi

TMP_PAYLOAD="$(mktemp -d)"
mkdir -p "${TMP_PAYLOAD}/Payload"
cp -R "${APP_PATH}" "${TMP_PAYLOAD}/Payload/"
pushd "${TMP_PAYLOAD}" >/dev/null
zip -r "${IPA_OUTPUT}" Payload >/dev/null
popd >/dev/null
mv "${IPA_OUTPUT}" "${ROOT}/" 2>/dev/null || true
IPA_FILE="$(basename "${IPA_OUTPUT}")"
echo "✅ Created unsigned IPA: ${ROOT}/${IPA_FILE}"

echo "✅ Unsigned iOS build finished."
