param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

. (Join-Path $PSScriptRoot "tools\project_env.ps1")

function Get-ConfigMap {
    param([string]$Path)

    $map = @{}
    foreach ($line in Get-Content $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) {
            continue
        }
        $parts = $trimmed -split '=', 2
        if ($parts.Count -eq 2) {
            $map[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
    return $map
}

$config = Get-ConfigMap -Path $ConfigFile
$pythonExe = Resolve-ProjectPython -ProjectRoot $PSScriptRoot -AutoInit
$sshTool = Join-Path $PSScriptRoot "tools\remote_ssh.py"

$remoteUser = $config["REMOTE_USER"]
$remoteHost = $config["REMOTE_HOST"]
$remotePort = $config["REMOTE_PORT"]
$remotePassword = $config["REMOTE_PASSWORD"]
$remoteHome = $config["REMOTE_HOME"]
$ccswitchRemotePort = if ($config.ContainsKey("CCSWITCH_REMOTE_PORT")) { $config["CCSWITCH_REMOTE_PORT"] } else { "43141" }

$remoteCmd = @"
python3 - <<'PY'
import json
from pathlib import Path
p = Path('${remoteHome}/.claude/settings.json')
data = {}
if p.exists():
    try:
        data = json.loads(p.read_text(encoding='utf-8'))
    except Exception:
        data = {}
env = data.setdefault('env', {})
env['ANTHROPIC_BASE_URL'] = 'http://localhost:${ccswitchRemotePort}'
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
PY
"@

Write-Host "[claude] configuring remote Claude Code to use http://localhost:$ccswitchRemotePort" -ForegroundColor Cyan
Write-Host "[env] python: $pythonExe" -ForegroundColor DarkGray
& $pythonExe $sshTool `
    --password $remotePassword `
    --user $remoteUser `
    --host $remoteHost `
    --port $remotePort `
    -- /bin/bash -lc $remoteCmd

if ($LASTEXITCODE -ne 0) {
    throw "remote Claude configuration failed"
}

Write-Host "[claude] remote Claude Code configuration updated" -ForegroundColor Green
