param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

. (Join-Path $PSScriptRoot "tools\project_env.ps1")

$ErrorActionPreference = "Stop"

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
$remoteHost = $config["REMOTE_HOST"]
$remotePort = $config["REMOTE_PORT"]
$remoteUser = $config["REMOTE_USER"]
$remotePassword = $config["REMOTE_PASSWORD"]
$remoteBindPort = if ($config.ContainsKey("REMOTE_PROXY_PORT")) { $config["REMOTE_PROXY_PORT"] } else { "38080" }
$localProxyPort = if ($config.ContainsKey("LOCAL_PROXY_PORT")) { $config["LOCAL_PROXY_PORT"] } else { "28080" }
$pythonExe = Resolve-ProjectPython -ProjectRoot $PSScriptRoot -AutoInit
$toolPath = Join-Path $PSScriptRoot "tools\remote_codex_bridge.py"

try {
    Write-Host "[codex] sync local state" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "sync_codex_state.ps1") -ConfigFile $ConfigFile
    Write-Host "[codex] configure remote proxy env" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "use_remote_local_proxy.ps1") -ConfigFile $ConfigFile
    Write-Host "[codex] stop old Windows bridge" -ForegroundColor Cyan
    $old = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^python(?:\.exe)?$' -and
        $_.CommandLine -like '*remote_codex_bridge.py*' -and
        $_.CommandLine -like "*--remote-port ${remoteBindPort}*"
    }
    foreach ($proc in $old) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[codex] local proxy endpoint: 127.0.0.1:$localProxyPort" -ForegroundColor DarkGray
    Write-Host "[codex] remote proxy endpoint: http://127.0.0.1:$remoteBindPort" -ForegroundColor DarkGray
    Write-Host "[env] python: $pythonExe" -ForegroundColor DarkGray
    Write-Host "[codex] foreground bridge starting; close this window to stop it" -ForegroundColor Yellow

    & $pythonExe $toolPath `
        --host $remoteHost `
        --port $remotePort `
        --user $remoteUser `
        --password $remotePassword `
        --remote-port $remoteBindPort `
        --local-proxy-port $localProxyPort
    exit $LASTEXITCODE
}
catch {
    Write-Host "[error] Codex start failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    $old = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^python(?:\.exe)?$' -and
        $_.CommandLine -like '*remote_codex_bridge.py*' -and
        $_.CommandLine -like "*--remote-port ${remoteBindPort}*"
    }
    foreach ($proc in $old) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }
    exit 1
}
