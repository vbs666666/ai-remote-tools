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

function Invoke-Upload {
    param(
        [string]$PythonExe,
        [string]$ScpTool,
        [string]$Password,
        [string]$RemoteUser,
        [string]$RemoteHost,
        [string]$RemotePort,
        [string]$Source,
        [string]$Destination
    )

    Write-Host "[sync-claude] upload $([System.IO.Path]::GetFileName($Source)) -> $Destination"
    & $PythonExe $ScpTool `
        --password $Password `
        --user $RemoteUser `
        --host $RemoteHost `
        --port $RemotePort `
        $Source `
        "${RemoteUser}@${RemoteHost}:${Destination}"

    if ($LASTEXITCODE -ne 0) {
        throw "upload failed: $Source"
    }
}

$config = Get-ConfigMap -Path $ConfigFile
$pythonExe = Resolve-ProjectPython -ProjectRoot $PSScriptRoot -AutoInit
$sshTool = Join-Path $PSScriptRoot "tools\remote_ssh.py"
$scpTool = Join-Path $PSScriptRoot "tools\remote_scp.py"
$baseWin = Join-Path $env:USERPROFILE ""

$remoteUser = $config["REMOTE_USER"]
$remoteHost = $config["REMOTE_HOST"]
$remotePort = $config["REMOTE_PORT"]
$remotePassword = $config["REMOTE_PASSWORD"]
$remoteHome = $config["REMOTE_HOME"]

Write-Host "[sync-claude] start" -ForegroundColor Cyan
Write-Host "[env] python: $pythonExe" -ForegroundColor DarkGray
Write-Host "[sync-claude] config: $ConfigFile" -ForegroundColor DarkGray
Write-Host "[sync-claude] target: ${remoteUser}@${remoteHost}:${remotePort}" -ForegroundColor DarkGray

& $pythonExe $sshTool `
    --password $remotePassword `
    --user $remoteUser `
    --host $remoteHost `
    --port $remotePort `
    -- /bin/mkdir -p "${remoteHome}/.claude" "${remoteHome}/.cc-switch"
if ($LASTEXITCODE -ne 0) { throw "remote mkdir failed" }

& $pythonExe $sshTool `
    --password $remotePassword `
    --user $remoteUser `
    --host $remoteHost `
    --port $remotePort `
    -- /bin/chmod 700 "${remoteHome}/.claude" "${remoteHome}/.cc-switch"
if ($LASTEXITCODE -ne 0) { throw "remote chmod failed" }

Invoke-Upload -PythonExe $pythonExe -ScpTool $scpTool -Password $remotePassword -RemoteUser $remoteUser -RemoteHost $remoteHost -RemotePort $remotePort -Source (Join-Path $baseWin ".claude\.credentials.json") -Destination "${remoteHome}/.claude/.credentials.json"
Invoke-Upload -PythonExe $pythonExe -ScpTool $scpTool -Password $remotePassword -RemoteUser $remoteUser -RemoteHost $remoteHost -RemotePort $remotePort -Source (Join-Path $baseWin ".claude\settings.json") -Destination "${remoteHome}/.claude/settings.json"
Invoke-Upload -PythonExe $pythonExe -ScpTool $scpTool -Password $remotePassword -RemoteUser $remoteUser -RemoteHost $remoteHost -RemotePort $remotePort -Source (Join-Path $baseWin ".claude\settings.local.json") -Destination "${remoteHome}/.claude/settings.local.json"
Invoke-Upload -PythonExe $pythonExe -ScpTool $scpTool -Password $remotePassword -RemoteUser $remoteUser -RemoteHost $remoteHost -RemotePort $remotePort -Source (Join-Path $baseWin ".claude.json") -Destination "${remoteHome}/.claude.json"
Invoke-Upload -PythonExe $pythonExe -ScpTool $scpTool -Password $remotePassword -RemoteUser $remoteUser -RemoteHost $remoteHost -RemotePort $remotePort -Source (Join-Path $baseWin ".cc-switch\settings.json") -Destination "${remoteHome}/.cc-switch/settings.json"
Invoke-Upload -PythonExe $pythonExe -ScpTool $scpTool -Password $remotePassword -RemoteUser $remoteUser -RemoteHost $remoteHost -RemotePort $remotePort -Source (Join-Path $baseWin ".cc-switch\cc-switch.db") -Destination "${remoteHome}/.cc-switch/cc-switch.db"

& $pythonExe $sshTool `
    --password $remotePassword `
    --user $remoteUser `
    --host $remoteHost `
    --port $remotePort `
    -- /bin/chmod 600 `
    "${remoteHome}/.claude/.credentials.json" `
    "${remoteHome}/.claude/settings.json" `
    "${remoteHome}/.claude/settings.local.json" `
    "${remoteHome}/.claude.json" `
    "${remoteHome}/.cc-switch/settings.json" `
    "${remoteHome}/.cc-switch/cc-switch.db"
if ($LASTEXITCODE -ne 0) { throw "remote chmod final failed" }

Write-Host "[sync-claude] done" -ForegroundColor Green
