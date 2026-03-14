#!/usr/bin/env bash
set -euo pipefail

REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_HOST="${REMOTE_HOST:-connect.bjb1.seetacloud.com}"
REMOTE_PORT="${REMOTE_PORT:-15570}"
REMOTE_PASSWORD="${REMOTE_PASSWORD:-}"
REMOTE_HOME="${REMOTE_HOME:-/root}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLS_DIR="${ROOT_DIR}/tools"
SCRIPTS_DIR="${ROOT_DIR}/scripts"

if [ -z "$REMOTE_PASSWORD" ]; then
  echo "REMOTE_PASSWORD is required" >&2
  exit 1
fi

echo "[install] uploading bootstrap script to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_HOME}"

python3 "${TOOLS_DIR}/remote_scp.py" \
  --password "$REMOTE_PASSWORD" \
  --user "$REMOTE_USER" \
  --host "$REMOTE_HOST" \
  --port "$REMOTE_PORT" \
  "${SCRIPTS_DIR}/bootstrap_remote_ai.sh" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_HOME}/bootstrap_remote_ai.sh"

echo "[install] running remote bootstrap"
python3 "${TOOLS_DIR}/remote_ssh.py" \
  --password "$REMOTE_PASSWORD" \
  --user "$REMOTE_USER" \
  --host "$REMOTE_HOST" \
  --port "$REMOTE_PORT" \
  -- /bin/bash "${REMOTE_HOME}/bootstrap_remote_ai.sh"
echo "[install] done"
