#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLS_DIR="${ROOT_DIR}/tools"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/remote.env}"

set -a
source "$CONFIG_FILE"
set +a

echo "[codex] target: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT} remote SOCKS 127.0.0.1:${REMOTE_PROXY_PORT:-38080}"
exec python3 "${TOOLS_DIR}/remote_reverse_tunnel.py" \
  --host "${REMOTE_HOST}" \
  --port "${REMOTE_PORT}" \
  --user "${REMOTE_USER}" \
  --password "${REMOTE_PASSWORD}" \
  --remote-port "${REMOTE_PROXY_PORT:-38080}" \
  --remote-dynamic
