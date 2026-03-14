function Get-UvExe {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if ($uv) {
        return $uv.Source
    }
    return $null
}

function Get-ProjectPythonPath {
    param(
        [string]$ProjectRoot
    )

    return Join-Path $ProjectRoot ".venv\Scripts\python.exe"
}

function Initialize-ProjectPython {
    param(
        [string]$ProjectRoot
    )

    $uvExe = Get-UvExe
    if (-not $uvExe) {
        throw "uv not found. Install uv or run this project on a machine with uv available."
    }

    Write-Host "[env] project .venv not found; creating local environment with uv" -ForegroundColor Yellow
    & $uvExe sync --project $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "uv sync failed"
    }

    $projectPython = Get-ProjectPythonPath -ProjectRoot $ProjectRoot
    if (-not (Test-Path $projectPython)) {
        throw "project python not created: $projectPython"
    }
}

function Resolve-ProjectPython {
    param(
        [string]$ProjectRoot,
        [switch]$AutoInit
    )

    $projectPython = Get-ProjectPythonPath -ProjectRoot $ProjectRoot
    if (Test-Path $projectPython) {
        return $projectPython
    }

    if ($AutoInit) {
        Initialize-ProjectPython -ProjectRoot $ProjectRoot
        return (Get-ProjectPythonPath -ProjectRoot $ProjectRoot)
    }

    throw "project python missing: $projectPython"
}
