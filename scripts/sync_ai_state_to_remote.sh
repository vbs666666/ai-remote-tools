#!/usr/bin/env bash
set -euo pipefail

REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_HOST="${REMOTE_HOST:-connect.bjb1.seetacloud.com}"
REMOTE_PORT="${REMOTE_PORT:-15570}"
REMOTE_PASSWORD="${REMOTE_PASSWORD:-}"
REMOTE_HOME="${REMOTE_HOME:-/root}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASE_WIN="/mnt/c/Users/admin"
TOOLS_DIR="${ROOT_DIR}/tools"

if [ -z "$REMOTE_PASSWORD" ]; then
  echo "REMOTE_PASSWORD is required" >&2
  exit 1
fi

scp_py="${TOOLS_DIR}/remote_scp.py"
ssh_py="${TOOLS_DIR}/remote_ssh.py"

upload() {
  local src="$1"
  local dst="$2"
  echo "[sync] upload $(basename "$src") -> $dst"
  python3 "$scp_py" \
    --password "$REMOTE_PASSWORD" \
    --user "$REMOTE_USER" \
    --host "$REMOTE_HOST" \
    --port "$REMOTE_PORT" \
    "$src" "${REMOTE_USER}@${REMOTE_HOST}:${dst}"
}

run_remote() {
  python3 "$ssh_py" \
    --password "$REMOTE_PASSWORD" \
    --user "$REMOTE_USER" \
    --host "$REMOTE_HOST" \
    --port "$REMOTE_PORT" \
    -- "$@"
}

run_remote /bin/mkdir -p "${REMOTE_HOME}/.codex" "${REMOTE_HOME}/.claude" "${REMOTE_HOME}/.cc-switch"
run_remote /bin/chmod 700 "${REMOTE_HOME}/.codex" "${REMOTE_HOME}/.claude" "${REMOTE_HOME}/.cc-switch"

echo "[sync] syncing Codex state"

upload "${BASE_WIN}/.codex/auth.json" "${REMOTE_HOME}/.codex/auth.json"
upload "${BASE_WIN}/.codex/config.toml" "${REMOTE_HOME}/.codex/config.toml"

echo "[sync] syncing Claude and cc switch state"

upload "${BASE_WIN}/.claude/.credentials.json" "${REMOTE_HOME}/.claude/.credentials.json"
upload "${BASE_WIN}/.claude/settings.json" "${REMOTE_HOME}/.claude/settings.json"
upload "${BASE_WIN}/.claude/settings.local.json" "${REMOTE_HOME}/.claude/settings.local.json"
upload "${BASE_WIN}/.claude.json" "${REMOTE_HOME}/.claude.json"
upload "${BASE_WIN}/.cc-switch/settings.json" "${REMOTE_HOME}/.cc-switch/settings.json"
upload "${BASE_WIN}/.cc-switch/cc-switch.db" "${REMOTE_HOME}/.cc-switch/cc-switch.db"

run_remote /bin/chmod 600 \
  "${REMOTE_HOME}/.codex/auth.json" \
  "${REMOTE_HOME}/.codex/config.toml" \
  "${REMOTE_HOME}/.claude/.credentials.json" \
  "${REMOTE_HOME}/.claude/settings.json" \
  "${REMOTE_HOME}/.claude/settings.local.json" \
  "${REMOTE_HOME}/.claude.json" \
  "${REMOTE_HOME}/.cc-switch/settings.json" \
  "${REMOTE_HOME}/.cc-switch/cc-switch.db"

echo "sync complete"
