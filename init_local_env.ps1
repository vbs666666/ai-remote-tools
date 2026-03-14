param()

. (Join-Path $PSScriptRoot "tools\project_env.ps1")

Write-Host "[env] initialize local project environment" -ForegroundColor Cyan
$pythonExe = Resolve-ProjectPython -ProjectRoot $PSScriptRoot -AutoInit
Write-Host "[env] python: $pythonExe" -ForegroundColor Green
& $pythonExe -c "import paramiko; print('paramiko=' + paramiko.__version__)"
