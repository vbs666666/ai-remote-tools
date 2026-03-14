# ai-remote-tools

[![中文说明](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-blue)](./README_CN.md)

This project lets you use local `Codex` / `Claude Code` identity and network paths from a remote Linux server.

Chinese documentation:

- `README_CN.md`

## Entry Points

- `00_初始化本地环境.cmd`
- `01_安装并同步.cmd`
- `02_启动ClaudeCode.cmd`
- `03_启动Codex.cmd`
- `04_检查本机条件.cmd`

## Config

This project uses:

```text
remote.env
```

`remote.env` is intentionally ignored by Git and must be created locally.

The project `.venv` is not ignored.
This repository is intended to keep the local `uv` runtime environment in the project so it can be used directly after download on a similar Windows machine.

Quick setup:

```text
copy remote.env.example remote.env
```

Then edit at least:

- `REMOTE_USER`
- `REMOTE_HOST`
- `REMOTE_PORT`
- `REMOTE_PASSWORD`
- `REMOTE_HOME`

Usually you can leave these unchanged:

- `WSL_DISTRO`
- `REMOTE_PROXY_PORT`
- `LOCAL_PROXY_PORT`
- `CCSWITCH_LOCAL_PORT`
- `CCSWITCH_REMOTE_PORT`

## First Use

### 1. Initialize local runtime

Run:

```text
00_初始化本地环境.cmd
```

This creates or repairs the local `.venv` with `uv`.

Requirements:

- `uv` must be installed locally if `.venv` is missing or needs repair
- system Python is not required

### 2. Check local requirements

For a new machine, run:

```text
04_检查本机条件.cmd
```

It checks:

- `uv`
- project `.venv`
- `remote.env`
- required remote server fields
- local `Codex` state
- local `Claude / cc-switch` files

### 3. Create remote.env

Create:

```text
remote.env
```

from:

```text
remote.env.example
```

and fill in your remote server fields before running the daily scripts.

## Daily Use

### 1. Install and sync

Run:

```text
01_安装并同步.cmd
```

It will:

1. Check/install `Node`, `tmux`, `codex`, `claude` on the remote server
2. Sync local `Codex` state
3. Sync local `Claude / cc-switch` state

### 2. Start Claude Code

Run:

```text
02_启动ClaudeCode.cmd
```

It will:

1. Sync only `Claude / cc-switch`
2. Point remote `Claude Code` to local `cc switch / copilot-api`
3. Start a foreground reverse tunnel

Actual path:

```text
remote Claude Code
-> remote localhost:43141
-> SSH reverse forward
-> local localhost:4141
-> cc switch / copilot-api
```

Keep that window open. Closing it stops the Claude tunnel.

### 3. Start Codex

Run:

```text
03_启动Codex.cmd
```

It will:

1. Sync only `Codex`
2. Write remote `HTTP_PROXY / HTTPS_PROXY`
3. Start a foreground local HTTP proxy bridge plus reverse forward

Actual path:

```text
remote Codex
-> remote http://127.0.0.1:38080
-> SSH reverse forward
-> local HTTP CONNECT proxy
-> local network
-> chatgpt.com / OpenAI
```

Keep that window open. Closing it stops the Codex bridge.

## Important Notes

### Claude and Codex use different paths

- `Claude Code` uses `cc switch`
- `Codex` does not use `cc switch`

### Codex does not use local `cc switch default`

Current remote `Codex` uses:

- local `auth.json`
- local `config.toml`
- local proxy bridge

It is not currently routed through a local `cc switch default` endpoint.

### Starting Codex does not sync cc-switch

Sync is split into:

- `sync_codex_state.ps1`
- `sync_claude_state.ps1`

So:

- starting `Codex` syncs only `.codex`
- starting `Claude Code` syncs `.claude` and `.cc-switch`

## For Other Users

Someone else can use this project if they have:

- local `uv`
- their own local `Codex` login state
- if using `Claude`, their own local `Claude / cc-switch` state
- a reachable remote Linux server over SSH
- a properly filled `remote.env`

Recommended order:

1. `04_检查本机条件.cmd`
2. `00_初始化本地环境.cmd`
3. create `remote.env` from `remote.env.example`
4. `01_安装并同步.cmd`
5. `02_启动ClaudeCode.cmd` or `03_启动Codex.cmd`

## Verified

Verified working:

- `01_安装并同步.cmd`
- `02_启动ClaudeCode.cmd`
- `03_启动Codex.cmd`

Verified capabilities:

- remote `Claude Code` works through local `cc switch`
- remote `Codex` works through the local proxy bridge
- remote `codex exec --skip-git-repo-check 'Reply with OK only.'` returned success

## Security

- do not commit `auth.json`
- do not commit `remote.env`
- do not share `cc-switch.db` or Claude credentials
- closing `02` or `03` stops the matching remote tunnel
