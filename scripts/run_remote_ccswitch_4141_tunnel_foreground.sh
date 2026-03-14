#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLS_DIR="${ROOT_DIR}/tools"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/remote.env}"

set -a
source "$CONFIG_FILE"
set +a

echo "[claude] preflight: checking local 127.0.0.1:${CCSWITCH_LOCAL_PORT:-4141}"
echo "[claude] target: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT} remote 127.0.0.1:${CCSWITCH_REMOTE_PORT:-43141}"
exec python3 "${TOOLS_DIR}/remote_reverse_tunnel.py" \
  --host "${REMOTE_HOST}" \
  --port "${REMOTE_PORT}" \
  --user "${REMOTE_USER}" \
  --password "${REMOTE_PASSWORD}" \
  --remote-port "${CCSWITCH_REMOTE_PORT:-43141}" \
  --local-port "${CCSWITCH_LOCAL_PORT:-4141}"
