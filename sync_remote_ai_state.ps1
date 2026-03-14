param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

& (Join-Path $PSScriptRoot "sync_codex_state.ps1") -ConfigFile $ConfigFile
& (Join-Path $PSScriptRoot "sync_claude_state.ps1") -ConfigFile $ConfigFile
