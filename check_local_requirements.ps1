param()

. (Join-Path $PSScriptRoot "tools\project_env.ps1")

function Write-CheckOk {
    param([string]$Message)
    Write-Host "[ok] $Message" -ForegroundColor Green
}

function Write-CheckWarn {
    param([string]$Message)
    Write-Host "[warn] $Message" -ForegroundColor Yellow
}

function Write-CheckFail {
    param([string]$Message)
    Write-Host "[fail] $Message" -ForegroundColor Red
}

function Test-TcpPort {
    param(
        [string]$Host,
        [int]$Port
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($Host, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(1500, $false)) {
            $client.Close()
            return $false
        }
        $client.EndConnect($iar) | Out-Null
        $client.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Get-ConfigMap {
    param([string]$Path)

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

$projectRoot = $PSScriptRoot
$configPath = Join-Path $projectRoot "remote.env"
$failed = $false

Write-Host "[check] local requirements" -ForegroundColor Cyan
Write-Host "[check] project: $projectRoot" -ForegroundColor DarkGray

$uvExe = Get-UvExe
if ($uvExe) {
    Write-CheckOk "uv found: $uvExe"
}
else {
    Write-CheckFail "uv not found"
    $failed = $true
}

$projectPython = Get-ProjectPythonPath -ProjectRoot $projectRoot
if (Test-Path $projectPython) {
    Write-CheckOk "project python found: $projectPython"
}
else {
    Write-CheckWarn "project python missing: run 00_初始化本地环境.cmd"
}

if (Test-Path $configPath) {
    Write-CheckOk "config file found: $configPath"
}
else {
    Write-CheckFail "config file missing: $configPath"
    $failed = $true
}

$config = Get-ConfigMap -Path $configPath
foreach ($key in @("REMOTE_USER", "REMOTE_HOST", "REMOTE_PORT", "REMOTE_PASSWORD", "REMOTE_HOME")) {
    if ($config.ContainsKey($key) -and $config[$key]) {
        Write-CheckOk "config $key is set"
    }
    else {
        Write-CheckFail "config $key is missing"
        $failed = $true
    }
}

$codexAuth = Join-Path $env:USERPROFILE ".codex\auth.json"
$codexConfig = Join-Path $env:USERPROFILE ".codex\config.toml"
if (Test-Path $codexAuth) {
    Write-CheckOk "Codex auth found"
}
else {
    Write-CheckFail "Codex auth missing: $codexAuth"
    $failed = $true
}
if (Test-Path $codexConfig) {
    Write-CheckOk "Codex config found"
}
else {
    Write-CheckFail "Codex config missing: $codexConfig"
    $failed = $true
}

$claudeCred = Join-Path $env:USERPROFILE ".claude\.credentials.json"
$claudeSettings = Join-Path $env:USERPROFILE ".claude\settings.json"
$ccswitchSettings = Join-Path $env:USERPROFILE ".cc-switch\settings.json"
$ccswitchDb = Join-Path $env:USERPROFILE ".cc-switch\cc-switch.db"

if (Test-Path $claudeCred) {
    Write-CheckOk "Claude credentials found"
}
else {
    Write-CheckWarn "Claude credentials missing: $claudeCred"
}
if (Test-Path $claudeSettings) {
    Write-CheckOk "Claude settings found"
}
else {
    Write-CheckWarn "Claude settings missing: $claudeSettings"
}
if (Test-Path $ccswitchSettings) {
    Write-CheckOk "cc-switch settings found"
}
else {
    Write-CheckWarn "cc-switch settings missing: $ccswitchSettings"
}
if (Test-Path $ccswitchDb) {
    Write-CheckOk "cc-switch db found"
}
else {
    Write-CheckWarn "cc-switch db missing: $ccswitchDb"
}

Write-Host ""
if ($failed) {
    Write-Host "[summary] basic requirements are incomplete" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "[summary] basic requirements look good" -ForegroundColor Green
    exit 0
}
