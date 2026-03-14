param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

& (Join-Path $PSScriptRoot "sync_remote_ai_state.ps1") -ConfigFile $ConfigFile
& (Join-Path $PSScriptRoot "stop_remote_local_proxy_tunnel.ps1") -ConfigFile $ConfigFile
& (Join-Path $PSScriptRoot "start_remote_local_proxy_tunnel.ps1") -ConfigFile $ConfigFile
& (Join-Path $PSScriptRoot "use_remote_local_proxy.ps1") -ConfigFile $ConfigFile
