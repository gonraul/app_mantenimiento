param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Add-ToPathIfMissing {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) {
        return
    }

    $parts = $env:PATH -split ';'
    if ($parts -notcontains $Dir) {
        $env:PATH = "$Dir;$env:PATH"
    }
}

function Get-Node22Home {
    $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (-not (Test-Path $pkgRoot)) {
        return $null
    }

    $nodePkg = Get-ChildItem -Path $pkgRoot -Directory -Filter 'OpenJS.NodeJS.22*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $nodePkg) {
        return $null
    }

    return Get-ChildItem -Path $nodePkg.FullName -Directory -Filter 'node-v*-win-x64' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Get-JavaHome {
    $base = Join-Path $env:USERPROFILE 'tools\jdk17'
    if (-not (Test-Path $base)) {
        return $null
    }

    $dir = Get-ChildItem -Path $base -Directory -Filter 'jdk-*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $dir) {
        return $null
    }

    return $dir.FullName
}

function Get-AndroidSdkHome {
    $candidates = @(
        (Join-Path $env:USERPROFILE 'Android\Sdk'),
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate 'cmdline-tools\latest\bin\sdkmanager.bat')) {
            return $candidate
        }
    }

    return $null
}

$flutterHome = Join-Path $env:USERPROFILE 'tools\flutter\flutter'
if (-not (Test-Path (Join-Path $flutterHome 'bin\flutter.bat'))) {
    throw "Flutter no encontrado en $flutterHome"
}

$javaHome = Get-JavaHome
if (-not $javaHome -or -not (Test-Path (Join-Path $javaHome 'bin\java.exe'))) {
    throw 'Java 17 portable no encontrado en %USERPROFILE%\\tools\\jdk17'
}

$nodeHome = Get-Node22Home
if (-not $nodeHome -or -not (Test-Path (Join-Path $nodeHome 'node.exe'))) {
    throw 'Node 22 no encontrado. Instala con winget en scope user.'
}

$env:FLUTTER_HOME = $flutterHome
$env:JAVA_HOME = $javaHome
$env:NODE22_HOME = $nodeHome

$androidSdkHome = Get-AndroidSdkHome
if ($androidSdkHome) {
    $env:ANDROID_SDK_ROOT = $androidSdkHome
    $env:ANDROID_HOME = $androidSdkHome
    $env:JAVA_TOOL_OPTIONS = '-Djavax.net.ssl.trustStoreType=Windows-ROOT -Djavax.net.ssl.trustStore=NUL'
}

Add-ToPathIfMissing (Join-Path $env:FLUTTER_HOME 'bin')
Add-ToPathIfMissing (Join-Path $env:JAVA_HOME 'bin')
Add-ToPathIfMissing $env:NODE22_HOME
if ($androidSdkHome) {
    Add-ToPathIfMissing (Join-Path $androidSdkHome 'platform-tools')
    Add-ToPathIfMissing (Join-Path $androidSdkHome 'cmdline-tools\latest\bin')
}

$firebaseCmd = Join-Path $env:USERPROFILE 'tools\npm-global\firebase.cmd'
if (Test-Path $firebaseCmd) {
    $env:FIREBASE_CMD = $firebaseCmd
}

if (-not $Quiet) {
    Write-Output "FLUTTER_HOME=$env:FLUTTER_HOME"
    Write-Output "JAVA_HOME=$env:JAVA_HOME"
    Write-Output "NODE22_HOME=$env:NODE22_HOME"
    if ($androidSdkHome) {
        Write-Output "ANDROID_SDK_ROOT=$env:ANDROID_SDK_ROOT"
    }
    if ($env:FIREBASE_CMD) {
        Write-Output "FIREBASE_CMD=$env:FIREBASE_CMD"
    }

    & (Join-Path $env:FLUTTER_HOME 'bin\flutter.bat') --version
    & (Join-Path $env:JAVA_HOME 'bin\java.exe') --version
    & (Join-Path $env:NODE22_HOME 'node.exe') --version
    & (Join-Path $env:NODE22_HOME 'npm.cmd') --version

    if ($env:FIREBASE_CMD) {
        try {
            & $env:FIREBASE_CMD --version
        }
        catch {
            Write-Warning 'Firebase CLI detectado pero no funcional en este entorno corporativo.'
        }
    }
}
