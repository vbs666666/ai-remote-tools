param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

$script = ((Join-Path $PSScriptRoot "scripts\stop_remote_local_proxy_tunnel.sh") -replace '\\', '/').Replace('C:', '/mnt/c')
$distro = "Ubuntu-22.04"

if (Test-Path $ConfigFile) {
    $distroLine = Get-Content $ConfigFile | Where-Object { $_ -match '^WSL_DISTRO=' } | Select-Object -First 1
    if ($distroLine) {
        $distro = ($distroLine -split '=', 2)[1].Trim()
    }
}

wsl -d $distro bash -lc "bash '$script'"
