# ai-remote-tools

这个项目用于在远程 Linux 服务器上复用本地的 `Codex` / `Claude Code` 身份与网络链路。

## 入口脚本

- `00_初始化本地环境.cmd`
- `01_安装并同步.cmd`
- `02_启动ClaudeCode.cmd`
- `03_启动Codex.cmd`
- `04_检查本机条件.cmd`

## 配置文件

项目使用：

```text
remote.env
```

`remote.env` 含有敏感信息，不会上传到 GitHub，必须在本地自行创建。

创建方式：

```text
复制 remote.env.example 为 remote.env
```

至少需要修改这些字段：

- `REMOTE_USER`
- `REMOTE_HOST`
- `REMOTE_PORT`
- `REMOTE_PASSWORD`
- `REMOTE_HOME`

这些字段通常可以保持默认：

- `WSL_DISTRO`
- `REMOTE_PROXY_PORT`
- `LOCAL_PROXY_PORT`
- `CCSWITCH_LOCAL_PORT`
- `CCSWITCH_REMOTE_PORT`

项目内的 `.venv` 不会被忽略。
这个仓库默认保留项目本地的 `uv` 运行环境，便于在相似的 Windows 机器上下载后直接使用。

## 首次使用

### 1. 初始化本地运行环境

运行：

```text
00_初始化本地环境.cmd
```

这会使用 `uv` 创建或修复项目本地 `.venv`。

要求：

- 如果 `.venv` 缺失或损坏，本机需要安装 `uv`
- 不要求系统 Python

### 2. 检查本机条件

在新机器上，先运行：

```text
04_检查本机条件.cmd
```

它会检查：

- `uv`
- 项目 `.venv`
- `remote.env`
- 远程服务器必填字段
- 本地 `Codex` 状态文件
- 本地 `Claude / cc-switch` 文件

## 日常使用

### 1. 安装并同步

运行：

```text
01_安装并同步.cmd
```

它会：

1. 在远程服务器上检查或安装 `Node`、`tmux`、`codex`、`claude`
2. 同步本地 `Codex` 状态
3. 同步本地 `Claude / cc-switch` 状态

### 2. 启动 Claude Code

运行：

```text
02_启动ClaudeCode.cmd
```

它会：

1. 只同步 `Claude / cc-switch`
2. 把远程 `Claude Code` 指向本地 `cc switch / copilot-api`
3. 启动一个前台反向隧道

实际链路：

```text
远程 Claude Code
-> 远程 localhost:43141
-> SSH 反向转发
-> 本地 localhost:4141
-> cc switch / copilot-api
```

这个窗口要保持打开。关闭后，Claude 的远程隧道就会停止。

### 3. 启动 Codex

运行：

```text
03_启动Codex.cmd
```

它会：

1. 只同步 `Codex`
2. 写入远程 `HTTP_PROXY / HTTPS_PROXY`
3. 启动一个前台本地 HTTP 代理桥和反向转发

实际链路：

```text
远程 Codex
-> 远程 http://127.0.0.1:38080
-> SSH 反向转发
-> 本地 HTTP CONNECT 代理
-> 本地网络
-> chatgpt.com / OpenAI
```

这个窗口也要保持打开。关闭后，Codex 的代理桥会停止。

## 重要说明

### Claude 和 Codex 不是同一条链路

- `Claude Code` 使用 `cc switch`
- `Codex` 不使用 `cc switch`

### 当前 Codex 不走本地 `cc switch default`

当前远程 `Codex` 使用的是：

- 本地 `auth.json`
- 本地 `config.toml`
- 本地代理桥

它目前不是通过本地 `cc switch default` 端点转发的。

### 启动 Codex 不会同步 cc-switch

同步已经拆成：

- `sync_codex_state.ps1`
- `sync_claude_state.ps1`

所以：

- 启动 `Codex` 时只同步 `.codex`
- 启动 `Claude Code` 时同步 `.claude` 和 `.cc-switch`

## 给其他人使用时

别人要使用这个项目，需要满足：

- 本地已安装 `uv`
- 有自己的本地 `Codex` 登录状态
- 如果要用 `Claude`，还要有自己的本地 `Claude / cc-switch` 状态
- 有一台可以 SSH 登录的远程 Linux 服务器
- 正确填写 `remote.env`

推荐顺序：

1. `04_检查本机条件.cmd`
2. `00_初始化本地环境.cmd`
3. 根据 `remote.env.example` 创建 `remote.env`
4. `01_安装并同步.cmd`
5. `02_启动ClaudeCode.cmd` 或 `03_启动Codex.cmd`

## 已验证

已验证可用：

- `01_安装并同步.cmd`
- `02_启动ClaudeCode.cmd`
- `03_启动Codex.cmd`

已验证能力：

- 远程 `Claude Code` 可以通过本地 `cc switch` 工作
- 远程 `Codex` 可以通过本地代理桥工作
- 远程 `codex exec --skip-git-repo-check 'Reply with OK only.'` 返回成功

## 安全说明

- 不要提交 `auth.json`
- 不要提交 `remote.env`
- 不要分享 `cc-switch.db` 或 Claude 凭据
- 关闭 `02` 或 `03` 对应窗口时，会停止对应的远程隧道
