#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/remote.env}"
TOOLS_DIR="${ROOT_DIR}/tools"

set -a
source "$CONFIG_FILE"
set +a

echo "[claude] configuring remote Claude Code to use http://localhost:${CCSWITCH_REMOTE_PORT}"
python3 "${TOOLS_DIR}/remote_ssh.py" \
  --host "${REMOTE_HOST}" \
  --port "${REMOTE_PORT}" \
  --user "${REMOTE_USER}" \
  --password "${REMOTE_PASSWORD}" \
  -- /bin/bash -lc "python3 - <<'PY'
import json
from pathlib import Path
p = Path('${REMOTE_HOME}/.claude/settings.json')
data = {}
if p.exists():
    try:
        data = json.loads(p.read_text(encoding='utf-8'))
    except Exception:
        data = {}
env = data.setdefault('env', {})
env['ANTHROPIC_BASE_URL'] = 'http://localhost:${CCSWITCH_REMOTE_PORT}'
env.setdefault('ANTHROPIC_AUTH_TOKEN', 'dummy')
for key in [
    'ANTHROPIC_MODEL',
    'ANTHROPIC_REASONING_MODEL',
    'ANTHROPIC_DEFAULT_HAIKU_MODEL',
    'ANTHROPIC_DEFAULT_OPUS_MODEL',
    'ANTHROPIC_DEFAULT_SONNET_MODEL',
]:
    env.pop(key, None)
p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
print(p)
print(env['ANTHROPIC_BASE_URL'])
PY"
echo "[claude] remote Claude Code configuration updated"
