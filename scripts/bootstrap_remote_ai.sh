#!/usr/bin/env bash
set -euo pipefail

NODE_MAJOR="${NODE_MAJOR:-22}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/lib/ai-node}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

log() {
  printf '[bootstrap] %s\n' "$*"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

show_versions() {
  log "tmux version: $(tmux -V 2>/dev/null || echo 'missing')"
  log "node version: $(node -v 2>/dev/null || echo 'missing')"
  log "npm version: $(npm -v 2>/dev/null || echo 'missing')"
  log "codex version: $(codex --version 2>/dev/null || echo 'missing')"
  log "claude version: $(claude --version 2>/dev/null || echo 'missing')"
}

ensure_base_tools() {
  log "checking base tools"
  if ! have_cmd curl; then
    log "installing curl and ca-certificates"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates
  fi
  if ! have_cmd tar; then
    log "installing tar"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y tar
  fi
  if ! tar --help 2>/dev/null | grep -q -- '-J'; then
    log "installing xz-utils"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y xz-utils
  fi
  if ! have_cmd tmux; then
    log "installing tmux"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y tmux
  else
    log "tmux already present: $(tmux -V)"
  fi
}

latest_node_version() {
  local url data version
  for url in \
    "https://nodejs.org/dist/index.json" \
    "https://npmmirror.com/mirrors/node/index.json" \
    "https://cdn.npmmirror.com/binaries/node/index.json"
  do
    if data="$(curl -fsSL --max-time 20 "$url" 2>/dev/null)"; then
      version="$(printf '%s' "$data" | grep -o "\"version\":\"v${NODE_MAJOR}\\.[^\"]*\"" | head -n1 | cut -d'"' -f4)"
      if [ -n "${version:-}" ]; then
        printf '%s\n' "$version"
        return 0
      fi
    fi
  done
  return 1
}

install_node() {
  local version archive tmpdir target url
  version="$(latest_node_version)"
  log "installing Node ${version}"
  archive="node-${version}-linux-x64.tar.xz"
  tmpdir="$(mktemp -d)"

  for url in \
    "https://nodejs.org/dist/${version}/${archive}" \
    "https://npmmirror.com/mirrors/node/${version}/${archive}" \
    "https://cdn.npmmirror.com/binaries/node/${version}/${archive}"
  do
    if curl -fL --connect-timeout 15 --retry 3 --retry-delay 2 -o "${tmpdir}/${archive}" "$url"; then
      break
    fi
  done

  if [ ! -s "${tmpdir}/${archive}" ]; then
    log "failed to download ${archive}"
    return 1
  fi

  mkdir -p "$INSTALL_DIR"
  tar -xJf "${tmpdir}/${archive}" -C "$INSTALL_DIR"
  target="${INSTALL_DIR}/node-${version}-linux-x64"
  ln -sfn "$target" "${INSTALL_DIR}/current"
  ln -sfn "${INSTALL_DIR}/current/bin/node" "${BIN_DIR}/node"
  ln -sfn "${INSTALL_DIR}/current/bin/npm" "${BIN_DIR}/npm"
  ln -sfn "${INSTALL_DIR}/current/bin/npx" "${BIN_DIR}/npx"
  rm -rf "$tmpdir"
}

ensure_node() {
  if have_cmd node; then
    local current_major
    current_major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
    if [ "$current_major" = "$NODE_MAJOR" ]; then
      log "Node $(node -v) already present"
      return 0
    fi
  fi
  ensure_base_tools
  install_node
  log "Node installed: $(node -v)"
  log "npm installed: $(npm -v)"
}

install_cli() {
  local npm_prefix npm_bin
  log "installing Codex and Claude Code via ${NPM_REGISTRY}"
  npm config set registry "$NPM_REGISTRY"
  npm install -g @openai/codex @anthropic-ai/claude-code --no-fund --no-audit --loglevel=error
  npm_prefix="$(npm config get prefix)"
  npm_bin="${npm_prefix}/bin"
  if [ -x "${npm_bin}/codex" ]; then
    ln -sfn "${npm_bin}/codex" "${BIN_DIR}/codex"
  fi
  if [ -x "${npm_bin}/claude" ]; then
    ln -sfn "${npm_bin}/claude" "${BIN_DIR}/claude"
  fi
  show_versions
}

cli_ready() {
  have_cmd codex && have_cmd claude && have_cmd tmux
}

main() {
  log "starting remote bootstrap"
  ensure_base_tools
  ensure_node
  if cli_ready; then
    log "Codex, Claude Code, and tmux are already installed; skipping CLI install"
    show_versions
  else
    install_cli
  fi
  log "remote bootstrap complete"
}

main "$@"
