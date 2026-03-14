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
$scpTool = Join-Path $PSScriptRoot "tools\remote_scp.py"
$bootstrapScript = Join-Path $PSScriptRoot "scripts\bootstrap_remote_ai.sh"

$remoteUser = $config["REMOTE_USER"]
$remoteHost = $config["REMOTE_HOST"]
$remotePort = $config["REMOTE_PORT"]
$remotePassword = $config["REMOTE_PASSWORD"]
$remoteHome = $config["REMOTE_HOME"]

Write-Host "[install] start" -ForegroundColor Cyan
Write-Host "[env] python: $pythonExe" -ForegroundColor DarkGray
Write-Host "[install] config: $ConfigFile" -ForegroundColor DarkGray
Write-Host "[install] target: ${remoteUser}@${remoteHost}:${remotePort}" -ForegroundColor DarkGray
Write-Host "[install] upload bootstrap script" -ForegroundColor Cyan

& $pythonExe $scpTool `
    --password $remotePassword `
    --user $remoteUser `
    --host $remoteHost `
    --port $remotePort `
    $bootstrapScript `
    "${remoteUser}@${remoteHost}:${remoteHome}/bootstrap_remote_ai.sh"

if ($LASTEXITCODE -ne 0) {
    throw "bootstrap upload failed"
}

Write-Host "[install] run remote bootstrap" -ForegroundColor Cyan
& $pythonExe $sshTool `
    --password $remotePassword `
    --user $remoteUser `
    --host $remoteHost `
    --port $remotePort `
    -- /bin/bash "${remoteHome}/bootstrap_remote_ai.sh"

if ($LASTEXITCODE -ne 0) {
    throw "remote bootstrap failed"
}

Write-Host "[install] done" -ForegroundColor Green
