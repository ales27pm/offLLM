#!/bin/bash
set -euo pipefail

log() {
  printf '[patch-mlx-metal-cxx17] %s\n' "$1"
}

MARKER="offLLM:disable-metal-cxx17-warning"

apply_patch() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return
  fi

  local status
  status="$(python3 - "$file" "$MARKER" <<'PY'
import os
import sys
from typing import Tuple

path, marker = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as fh:
        original = fh.read()
except FileNotFoundError:
    print("missing", end="")
    raise SystemExit(0)

if marker in original:
    print("already", end="")
    raise SystemExit(0)

prefix = (
    f"// {marker}\n"
    "#if defined(__clang__)\n"
    "#pragma clang diagnostic push\n"
    "#pragma clang diagnostic ignored \"-Wc++17-extensions\"\n"
    "#endif\n"
)

suffix = (
    "\n#if defined(__clang__)\n"
    "#pragma clang diagnostic pop\n"
    "#endif\n"
)

content = original
if not content.endswith("\n"):
    content += "\n"

patched = prefix + content + suffix

tmp_path = path + ".offllm.tmp"
with open(tmp_path, "w", encoding="utf-8") as fh:
    fh.write(patched)
os.replace(tmp_path, path)
print("patched", end="")
PY
)"

  case "$status" in
    patched)
      log "Applied diagnostic guard to ${file}"
      ;;
    already)
      log "Already guarded ${file}"
      ;;
    missing)
      log "File disappeared before patch: ${file}"
      ;;
    "")
      log "No changes required for ${file}"
      ;;
    *)
      log "Unexpected status '${status}' for ${file}"
      ;;
  esac
}

collect_roots() {
  local candidate
  for candidate in "$@"; do
    if [ -d "$candidate" ]; then
      printf '%s\0' "$candidate"
    fi
  done
}

mapfile -d '' roots < <(collect_roots \
  "${PROJECT_DIR:-}"/SourcePackages/checkouts \
  "${PROJECT_DIR:-}"/../SourcePackages/checkouts \
  "${SRCROOT:-}"/SourcePackages/checkouts \
  "${DERIVED_DATA_DIR:-}"/SourcePackages/checkouts \
  "$HOME/Library/Developer/Xcode/DerivedData")

if [ "${#roots[@]}" -eq 0 ]; then
  log "No SourcePackages directories discovered; nothing to patch"
  exit 0
fi

declare -A seen_roots=()

for root in "${roots[@]}"; do
  if [ -z "$root" ]; then
    continue
  fi
  if [[ -n "${seen_roots[$root]:-}" ]]; then
    continue
  fi
  seen_roots[$root]=1

done

if [ "${#seen_roots[@]}" -eq 0 ]; then
  log "No unique SourcePackages directories found; exiting"
  exit 0
fi

patched_any=false

for root in "${!seen_roots[@]}"; do
  while IFS= read -r -d '' file; do
    apply_patch "$file"
    patched_any=true
  done < <(find "$root" -maxdepth 15 -path '*/mlx-swift/Source/Cmlx/mlx-generated/metal/steel/attn/kernels/steel_attention.h' -print0 || true)
done

if [ "$patched_any" = false ]; then
  log "Did not locate mlx-swift steel_attention.h; nothing to patch"
fi
