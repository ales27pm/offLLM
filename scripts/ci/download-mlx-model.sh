#!/usr/bin/env bash
set -euo pipefail

# Download the bundled MLX model for iOS builds so archives ship with weights.
#
# Environment variables:
#   MODEL_ID                Hugging Face repo id (default: Qwen/Qwen2-1.5B-Instruct-MLX)
#   MODEL_REVISION          Revision/branch to download (default: main)
#   MODEL_ROOT              Destination root for bundled models
#                            (default: ios/MyOfflineLLMApp/Models)
#   PYTHON_BIN              Python executable to use (default: python3)
#   MODEL_VENV_DIR          Optional path to reuse a Python virtualenv for dependencies
#   CI_FORCE_MODEL_REFRESH  When non-zero, remove any cached copy and redownload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MODEL_ID="${MODEL_ID:-Qwen/Qwen2-1.5B-Instruct-MLX}"
MODEL_REVISION="${MODEL_REVISION:-main}"
MODEL_ROOT="${MODEL_ROOT:-${REPO_ROOT}/ios/MyOfflineLLMApp/Models}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
HOST_PYTHON="$PYTHON_BIN"
TARGET_DIR="${MODEL_ROOT}/${MODEL_ID}"

log() {
  printf '==> %s\n' "$*"
}

die() {
  printf '::error::%s\n' "$*" >&2
  exit 1
}

dir_has_contents() {
  local dir="$1"
  [[ -d "$dir" ]] && [[ -n "$(ls -A -- "$dir" 2>/dev/null)" ]]
}

if ! command -v "$HOST_PYTHON" >/dev/null 2>&1; then
  die "Python interpreter '$PYTHON_BIN' not found"
fi

if [[ "${CI_FORCE_MODEL_REFRESH:-0}" != "0" ]]; then
  log "CI_FORCE_MODEL_REFRESH enabled; removing existing model at ${TARGET_DIR}"
  rm -rf "$TARGET_DIR"
fi

if [[ -d "$TARGET_DIR" ]] && find "$TARGET_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.mlx' \) -print -quit | grep -q .; then
  log "Model artifacts (.safetensors/.gguf/.mlx) already present at ${TARGET_DIR}; skipping download."
  exit 0
fi

log "Ensuring destination ${TARGET_DIR} exists"
mkdir -p "$TARGET_DIR"

if [[ -n "${MODEL_VENV_DIR:-}" ]]; then
  VENV_DIR="$MODEL_VENV_DIR"
  CLEANUP_VENV=0
else
  VENV_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mlx-model-venv-XXXXXXXX")"
  CLEANUP_VENV=1
fi

cleanup() {
  if [[ "${CLEANUP_VENV:-0}" -eq 1 ]]; then
    rm -rf "$VENV_DIR"
  fi
}
trap cleanup EXIT

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  if [[ "${CLEANUP_VENV:-0}" -eq 0 ]] && dir_has_contents "$VENV_DIR"; then
    die "MODEL_VENV_DIR '${VENV_DIR}' exists but does not look like an empty Python virtual environment"
  fi
  if [[ "${CLEANUP_VENV:-0}" -eq 1 ]]; then
    rm -rf "$VENV_DIR"
  fi
  log "Creating Python virtual environment at ${VENV_DIR}"
  "$HOST_PYTHON" -m venv "$VENV_DIR" || die "Failed to create Python virtual environment at ${VENV_DIR}"
else
  log "Reusing Python virtual environment at ${VENV_DIR}"
fi

PYTHON_BIN="${VENV_DIR}/bin/python"

log "Installing huggingface_hub dependency inside ${VENV_DIR} (quietly)"
"$PYTHON_BIN" -m pip install --upgrade --quiet pip
"$PYTHON_BIN" -m pip install --upgrade --quiet "huggingface_hub>=0.24.0,<0.25.0"

log "Downloading ${MODEL_ID}@${MODEL_REVISION}"
MODEL_ID="$MODEL_ID" \
MODEL_REVISION="$MODEL_REVISION" \
TARGET_DIR="$TARGET_DIR" \
"$PYTHON_BIN" <<'PY'
import os
from huggingface_hub import snapshot_download

model_id = os.environ["MODEL_ID"]
revision = os.environ["MODEL_REVISION"]
target_dir = os.environ["TARGET_DIR"]

snapshot_download(
    repo_id=model_id,
    revision=revision,
    local_dir=target_dir,
    local_dir_use_symlinks=False,
    allow_patterns=None,
)
PY

if ! find "$TARGET_DIR" -type f \( -name '*.safetensors' -o -name '*.gguf' -o -name '*.mlx' \) -print -quit | grep -q .; then
  die "Downloaded model at ${TARGET_DIR} does not contain expected .safetensors, .gguf, or .mlx weight files"
fi

log "Bundled MLX model ready at ${TARGET_DIR}"
