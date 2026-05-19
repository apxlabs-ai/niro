# Niro installer for Windows (PowerShell).
#
# Usage:
#   irm https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.ps1 | iex
#
# Environment variables:
#   NIRO_VERSION       Pin to a specific tag (e.g. v0.1.0). Defaults to latest.
#   NIRO_INSTALL_DIR   Override install directory.
#                      Defaults to %LOCALAPPDATA%\Programs\niro.

$ErrorActionPreference = 'Stop'

$Repo       = 'apxlabs-ai/niro'
$BinName    = 'niro.exe'
$InstallDir = if ($env:NIRO_INSTALL_DIR) {
    $env:NIRO_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA 'Programs\niro'
}

$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'amd64' }
    'ARM64' { 'arm64' }
    default { throw "Unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
}

$version = if ($env:NIRO_VERSION) { $env:NIRO_VERSION } else { 'latest' }
$archive = "niro_windows_${arch}.zip"
$baseUrl = if ($version -eq 'latest') {
    "https://github.com/$Repo/releases/latest/download"
} else {
    "https://github.com/$Repo/releases/download/$version"
}

$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "niro-install-$(Get-Random)")
try {
    Write-Host "Downloading $archive"
    Invoke-WebRequest -Uri "$baseUrl/$archive" `
                      -OutFile (Join-Path $tmp $archive) `
                      -UseBasicParsing

    Write-Host "Verifying checksum"
    $checksumsPath = Join-Path $tmp 'checksums.txt'
    Invoke-WebRequest -Uri "$baseUrl/checksums.txt" `
                      -OutFile $checksumsPath `
                      -UseBasicParsing

    $expected = (Get-Content $checksumsPath |
        Where-Object { $_ -match "\s$([regex]::Escape($archive))\s*$" }) `
        -split '\s+' | Select-Object -First 1
    if (-not $expected) { throw "Archive $archive not found in checksums.txt" }

    $actual = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $tmp $archive)).Hash.ToLower()
    if ($actual -ne $expected.ToLower()) {
        throw "Checksum mismatch: expected $expected, got $actual"
    }

    Write-Host "Extracting"
    Expand-Archive -Path (Join-Path $tmp $archive) -DestinationPath $tmp -Force

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Move-Item -Force `
        -Path (Join-Path $tmp $BinName) `
        -Destination (Join-Path $InstallDir $BinName)

    Write-Host ""
    Write-Host "Installed niro ($version) to $InstallDir\$BinName"

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$InstallDir", 'User')
        Write-Host ""
        Write-Host "Added $InstallDir to your user PATH."
        Write-Host "Open a new terminal for the change to take effect."
    }
} finally {
    Remove-Item -Recurse -Force -Path $tmp -ErrorAction SilentlyContinue
}
