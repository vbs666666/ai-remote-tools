#!/usr/bin/env bash
set -euo pipefail

echo '---PATH---'
echo "$PATH"
echo '---VERSIONS---'
command -v node || true
node -v || true
command -v npm || true
npm -v || true
echo '---NPM PREFIX---'
npm config get prefix || true
echo '---NPM ROOT---'
npm root -g || true
echo '---GLOBAL BIN CANDIDATES---'
find /usr/local -maxdepth 5 \( -name codex -o -name claude -o -path '*/node_modules/.bin/*' \) 2>/dev/null | sed -n '1,120p'
echo '---NODE MODULES---'
find /usr/local -maxdepth 5 \( -path '*/node_modules/@openai/codex' -o -path '*/node_modules/@anthropic-ai/claude-code' \) 2>/dev/null | sed -n '1,40p'
