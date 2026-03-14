#!/usr/bin/env bash
set -euo pipefail

backup=""
if [ -f /root/.claude/settings.json ]; then
  backup="/root/.claude/settings.json.remotebak"
  cp /root/.claude/settings.json "$backup"
fi

restore() {
  if [ -n "$backup" ] && [ -f "$backup" ]; then
    mv -f "$backup" /root/.claude/settings.json
  else
    rm -f /root/.claude/settings.json
  fi
}
trap restore EXIT

printf '{}\n' > /root/.claude/settings.json

ALL_PROXY=socks5h://127.0.0.1:39080 \
HTTPS_PROXY=socks5h://127.0.0.1:39080 \
HTTP_PROXY=socks5h://127.0.0.1:39080 \
NO_PROXY=localhost,127.0.0.1,::1 \
/usr/bin/timeout 120 claude -p 'Reply with OK only.'
