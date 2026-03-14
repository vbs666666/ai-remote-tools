#!/usr/bin/env bash
set -euo pipefail

whoami
uname -a
sed -n '1,12p' /etc/os-release

echo '---NODE---'
command -v node || true
node -v || true
command -v npm || true
npm -v || true

echo '---NETWORK---'
curl -I --max-time 12 https://registry.npmjs.org 2>/dev/null | sed -n '1,5p' || true
curl -I --max-time 12 https://registry.npmmirror.com 2>/dev/null | sed -n '1,5p' || true
curl -I --max-time 12 https://nodejs.org/dist/index.json 2>/dev/null | sed -n '1,5p' || true
curl -I --max-time 12 https://npmmirror.com/mirrors/node/index.json 2>/dev/null | sed -n '1,5p' || true

echo '---DISK---'
df -h / | sed -n '1,3p'
