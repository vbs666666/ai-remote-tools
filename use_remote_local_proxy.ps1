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
$remoteProxyPort = if ($config.ContainsKey("REMOTE_PROXY_PORT")) { $config["REMOTE_PROXY_PORT"] } else { "38080" }

Write-Host "[codex] writing remote proxy env: http://127.0.0.1:$remoteProxyPort" -ForegroundColor Cyan
Write-Host "[env] python: $pythonExe" -ForegroundColor DarkGray
& $pythonExe $sshTool `
    --password $remotePassword `
    --user $remoteUser `
    --host $remoteHost `
    --port $remotePort `
    -- /bin/bash -lc "cat > /etc/profile.d/ai-remote-proxy.sh <<'EOF'
export HTTP_PROXY=http://127.0.0.1:${remoteProxyPort}
export HTTPS_PROXY=http://127.0.0.1:${remoteProxyPort}
export ALL_PROXY=http://127.0.0.1:${remoteProxyPort}
export NO_PROXY=localhost,127.0.0.1,::1
EOF
chmod 644 /etc/profile.d/ai-remote-proxy.sh"

if ($LASTEXITCODE -ne 0) {
    throw "remote proxy env configuration failed"
}

Write-Host "[codex] remote proxy env configured" -ForegroundColor Green
