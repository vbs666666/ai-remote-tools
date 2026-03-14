param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

& (Join-Path $PSScriptRoot "sync_remote_ai_state.ps1") -ConfigFile $ConfigFile
& (Join-Path $PSScriptRoot "stop_remote_ccswitch_4141_tunnel.ps1") -ConfigFile $ConfigFile
& (Join-Path $PSScriptRoot "start_remote_ccswitch_4141_tunnel.ps1") -ConfigFile $ConfigFile
& (Join-Path $PSScriptRoot "configure_remote_claude_ccswitch_port.ps1") -ConfigFile $ConfigFile
