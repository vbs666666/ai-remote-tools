#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLS_DIR="${ROOT_DIR}/tools"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/remote.env}"
LOCAL_PORT="${CCSWITCH_LOCAL_PORT:-4141}"
REMOTE_BIND_PORT="${CCSWITCH_REMOTE_PORT:-43141}"
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
  --remote-port "${REMOTE_BIND_PORT}" \
  --local-port "${LOCAL_PORT}" \
  >"${PID_DIR}/ccswitch_4141_tunnel.out" 2>"${PID_DIR}/ccswitch_4141_tunnel.err" </dev/null &
pid=$!
echo "$pid" > "${PID_DIR}/ccswitch_4141_tunnel.pid"
sleep 1
if ! kill -0 "$pid" 2>/dev/null; then
  echo "4141 tunnel failed to stay alive" >&2
  sed -n '1,120p' "${PID_DIR}/ccswitch_4141_tunnel.err" >&2 || true
  exit 1
fi

echo "remote localhost:${REMOTE_BIND_PORT} -> local localhost:${LOCAL_PORT}"
