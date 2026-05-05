param(
    [ValidateSet('inicio', 'cierre')]
    [string]$Modo = 'inicio',
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot   = Split-Path -Parent $scriptDir

Push-Location $repoRoot
try {
    Write-Output "==> sync_and_check.ps1 | modo: $Modo"

    # --- INICIO DE JORNADA ---
    if ($Modo -eq 'inicio') {
        Write-Output '==> git pull --rebase origin main'
        git pull --rebase origin main
        if ($LASTEXITCODE -ne 0) {
            Write-Error 'El rebase fallo. Resolve los conflictos con git status y luego git rebase --continue'
        }

        Write-Output '==> Preparando entorno (dev_env.ps1)'
        . (Join-Path $scriptDir 'dev_env.ps1') -Quiet

        Write-Output '==> git status'
        git status --short --branch

        Write-Output 'OK: entorno listo para trabajar.'
    }

    # --- CIERRE DE JORNADA ---
    if ($Modo -eq 'cierre') {
        Write-Output '==> Preparando entorno (dev_env.ps1)'
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
            Write-Output '==> flutter test: omitido (-SkipTests)'
        }

        Write-Output '==> git status'
        git status --short --branch

        $msg = Read-Host 'Mensaje de commit (dejar vacio para no commitear)'
        if ($msg -ne '') {
            git add -A
            git commit -m $msg

            Write-Output '==> git pull --rebase origin main (antes del push)'
            git pull --rebase origin main
            if ($LASTEXITCODE -ne 0) {
                Write-Error 'El rebase fallo. Resolve los conflictos con git status y luego git rebase --continue'
            }

            Write-Output '==> git push origin main'
            git push origin main

            Write-Output 'OK: cambios subidos al repositorio.'
        }
        else {
            Write-Output 'Sin commit. Flujo de cierre finalizado.'
        }
    }
}
finally {
    Pop-Location
}
