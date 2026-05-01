param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Get-NodeHome {
    $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (-not (Test-Path $pkgRoot)) {
        return $null
    }

    $candidateDirs = Get-ChildItem -Path $pkgRoot -Directory -Filter 'OpenJS.NodeJS.22*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    foreach ($dir in $candidateDirs) {
        $nodeDir = Get-ChildItem -Path $dir.FullName -Directory -Filter 'node-v*-win-x64' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($nodeDir -and (Test-Path (Join-Path $nodeDir.FullName 'node.exe'))) {
            return $nodeDir.FullName
        }
    }

    return $null
}

$nodeHome = Get-NodeHome
if (-not $nodeHome) {
    Write-Error 'Node 22 no encontrado. Instala con: winget install --id OpenJS.NodeJS.22 --exact --source winget --scope user --silent --accept-package-agreements --accept-source-agreements'
}

$env:NODE22_HOME = $nodeHome
if (($env:PATH -split ';') -notcontains $nodeHome) {
    $env:PATH = "$nodeHome;$env:PATH"
}

if (-not $Quiet) {
    Write-Output "NODE22_HOME=$nodeHome"
    & (Join-Path $nodeHome 'node.exe') --version
    & (Join-Path $nodeHome 'npm.cmd') --version
}
