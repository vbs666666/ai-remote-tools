#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/remote.env}"
REMOTE_PROXY_PORT="${REMOTE_PROXY_PORT:-38080}"
TOOLS_DIR="${ROOT_DIR}/tools"

set -a
source "$CONFIG_FILE"
set +a

echo "[codex] writing remote proxy env: socks5h://127.0.0.1:${REMOTE_PROXY_PORT}"
python3 "${TOOLS_DIR}/remote_ssh.py" \
  --host "${REMOTE_HOST}" \
  --port "${REMOTE_PORT}" \
  --user "${REMOTE_USER}" \
  --password "${REMOTE_PASSWORD}" \
  -- /bin/bash -lc "cat > /etc/profile.d/ai-remote-proxy.sh <<'EOF'
export HTTP_PROXY=socks5h://127.0.0.1:${REMOTE_PROXY_PORT}
export HTTPS_PROXY=socks5h://127.0.0.1:${REMOTE_PROXY_PORT}
export ALL_PROXY=socks5h://127.0.0.1:${REMOTE_PROXY_PORT}
export NO_PROXY=localhost,127.0.0.1,::1
EOF
chmod 644 /etc/profile.d/ai-remote-proxy.sh"

echo "remote proxy env configured"
