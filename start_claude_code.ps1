param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

. (Join-Path $PSScriptRoot "tools\project_env.ps1")

$ErrorActionPreference = "Stop"

function Get-ConfigValue {
    param(
        [string]$Path
    )

    $map = @{}
    if (-not (Test-Path $Path)) {
        return $map
    }

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

$config = Get-ConfigValue -Path $ConfigFile
$remoteHost = $config["REMOTE_HOST"]
$remotePort = $config["REMOTE_PORT"]
$remoteUser = $config["REMOTE_USER"]
$remotePassword = $config["REMOTE_PASSWORD"]
$remoteBindPort = if ($config.ContainsKey("CCSWITCH_REMOTE_PORT")) { $config["CCSWITCH_REMOTE_PORT"] } else { "43141" }
$localPort = if ($config.ContainsKey("CCSWITCH_LOCAL_PORT")) { $config["CCSWITCH_LOCAL_PORT"] } else { "4141" }
$pythonExe = Resolve-ProjectPython -ProjectRoot $PSScriptRoot -AutoInit
$toolPath = Join-Path $PSScriptRoot "tools\remote_reverse_tunnel.py"

Write-Host "[claude] sync local state" -ForegroundColor Cyan
try {
    & (Join-Path $PSScriptRoot "sync_claude_state.ps1") -ConfigFile $ConfigFile
    Write-Host "[claude] configure remote base url" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "configure_remote_claude_ccswitch_port.ps1") -ConfigFile $ConfigFile

    Write-Host "[claude] stop old Windows tunnel" -ForegroundColor Cyan
    $old = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^python(?:\.exe)?$' -and
        $_.CommandLine -like '*remote_reverse_tunnel.py*' -and
        $_.CommandLine -like "*--remote-port ${remoteBindPort}*"
    }
    foreach ($proc in $old) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[claude] local endpoint: 127.0.0.1:$localPort" -ForegroundColor DarkGray
    Write-Host "[claude] remote endpoint: 127.0.0.1:$remoteBindPort" -ForegroundColor DarkGray
    Write-Host "[env] python: $pythonExe" -ForegroundColor DarkGray
    Write-Host "[claude] foreground tunnel starting; close this window to stop it" -ForegroundColor Green

    & $pythonExe $toolPath `
        --host $remoteHost `
        --port $remotePort `
        --user $remoteUser `
        --password $remotePassword `
        --remote-port $remoteBindPort `
        --local-port $localPort
    exit $LASTEXITCODE
}
catch {
    Write-Host "[error] Claude start failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    $old = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^python(?:\.exe)?$' -and
        $_.CommandLine -like '*remote_reverse_tunnel.py*' -and
        $_.CommandLine -like "*--remote-port ${remoteBindPort}*"
    }
    foreach ($proc in $old) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }
    exit 1
}
