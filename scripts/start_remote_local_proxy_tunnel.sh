#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLS_DIR="${ROOT_DIR}/tools"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/remote.env}"
REMOTE_PROXY_PORT="${REMOTE_PROXY_PORT:-38080}"
PID_DIR="${PID_DIR:-$HOME/.cache/ai-remote-tools}"

mkdir -p "$PID_DIR"

set -a
source "$CONFIG_FILE"
set +a

nohup python3 "${TOOLS_DIR}/remote_reverse_tunnel.py" \
  --host "${REMOTE_HOST}" \
  --port "${REMOTE_PORT}" \
  --user "${REMOTE_USER}" \
  --password "${REMOTE_PASSWORD}" \
  --remote-port "${REMOTE_PROXY_PORT}" \
  --remote-dynamic \
  >"${PID_DIR}/reverse_tunnel.out" 2>"${PID_DIR}/reverse_tunnel.err" </dev/null &
echo $! > "${PID_DIR}/reverse_tunnel.pid"

echo "remote socks proxy: 127.0.0.1:${REMOTE_PROXY_PORT}"
echo "pids saved in ${PID_DIR}"
