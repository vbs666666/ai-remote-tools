param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "[entry] install and sync start" -ForegroundColor Green
    & (Join-Path $PSScriptRoot "install_remote_ai.ps1") -ConfigFile $ConfigFile
    & (Join-Path $PSScriptRoot "sync_remote_ai_state.ps1") -ConfigFile $ConfigFile
    Write-Host "[entry] install and sync done" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "[error] install and sync failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
