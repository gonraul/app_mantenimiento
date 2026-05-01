param(
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

Push-Location $repoRoot
try {
    # Standardize local toolchain in every terminal session.
    . (Join-Path $scriptDir 'dev_env.ps1') -Quiet

    Write-Output '==> flutter pub get'
    flutter pub get

    Write-Output '==> flutter analyze'
    flutter analyze

    if (-not $SkipTests) {
        Write-Output '==> flutter test'
        flutter test
    }
    else {
        Write-Output '==> Skip tests enabled'
    }

    Write-Output 'OK: validacion completa finalizada.'
}
finally {
    Pop-Location
}
