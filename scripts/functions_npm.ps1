param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$NpmArgs
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'use_node22.ps1') -Quiet

if (-not $NpmArgs -or $NpmArgs.Count -eq 0) {
    $NpmArgs = @('install')
}

$repoRoot = Split-Path -Parent $scriptDir
$functionsDir = Join-Path $repoRoot 'functions'

if (-not (Test-Path (Join-Path $functionsDir 'package.json'))) {
    Write-Error "No se encontro package.json en $functionsDir"
}

Push-Location $functionsDir
try {
    Write-Output ("Ejecutando npm en {0}: npm {1}" -f $functionsDir, ($NpmArgs -join ' '))
    & (Join-Path $env:NODE22_HOME 'npm.cmd') @NpmArgs
}
finally {
    Pop-Location
}
