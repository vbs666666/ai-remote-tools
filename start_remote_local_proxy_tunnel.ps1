param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "remote.env")
)

$wslConfig = ($ConfigFile -replace '\\', '/').Replace('C:', '/mnt/c')
$script = ((Join-Path $PSScriptRoot "scripts\start_remote_local_proxy_tunnel.sh") -replace '\\', '/').Replace('C:', '/mnt/c')
$distro = "Ubuntu-22.04"

if (Test-Path $ConfigFile) {
    $distroLine = Get-Content $ConfigFile | Where-Object { $_ -match '^WSL_DISTRO=' } | Select-Object -First 1
    if ($distroLine) {
        $distro = ($distroLine -split '=', 2)[1].Trim()
    }
}

$cmd = @"
export CONFIG_FILE='$wslConfig'
bash '$script'
"@

wsl -d $distro bash -lc $cmd
