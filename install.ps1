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

function Write-Warn($msg) {
    Write-Host ""
    Write-Host "Warning: " -ForegroundColor Yellow -NoNewline
    Write-Host $msg
}

# OSC 8 hyperlinks render URLs as clickable in modern terminals
# (Windows Terminal, VSCode, recent ConEmu). Older conhost drops
# the escape silently. Skip when output isn't a real console host
# (transcript, redirection) or NO_COLOR is set.
$script:SupportsLinks = $Host.UI.SupportsVirtualTerminal -and -not $env:NO_COLOR
function Url-Link($url) {
    if ($script:SupportsLinks) {
        $esc = [char]27
        "$esc]8;;$url$esc\$url$esc]8;;$esc\"
    } else {
        $url
    }
}

$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'amd64' }
    'ARM64' { 'arm64' }
    default { throw "unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
}

$version = if ($env:NIRO_VERSION) { $env:NIRO_VERSION } else { 'latest' }
$archive = "niro_windows_${arch}.zip"
$baseUrl = if ($version -eq 'latest') {
    # Resolve "latest" to the concrete tag so progress and success
    # lines show what the user actually got. /releases/latest 302-
    # redirects to /releases/tag/<vX.Y.Z>; follow it and lift the tag
    # off the final URL. Best-effort: on failure keep "latest" and
    # let the download go through the same redirect.
    try {
        $resp = Invoke-WebRequest -Uri "https://github.com/$Repo/releases/latest" -UseBasicParsing
        $resolved = $resp.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
        if ($resolved -match '/releases/tag/([^/]+)$') { $version = $matches[1] }
    } catch { }
    "https://github.com/$Repo/releases/latest/download"
} else {
    "https://github.com/$Repo/releases/download/$version"
}

$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "niro-install-$(Get-Random)")
try {
    Write-Host "Downloading niro $version (windows/$arch)"
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
    if (-not $expected) { throw "archive $archive not found in checksums.txt" }

    $actual = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $tmp $archive)).Hash.ToLower()
    if ($actual -ne $expected.ToLower()) {
        throw "checksum mismatch: expected $expected, got $actual"
    }

    Expand-Archive -Path (Join-Path $tmp $archive) -DestinationPath $tmp -Force

    Write-Host "Installing to $InstallDir\$BinName"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Move-Item -Force `
        -Path (Join-Path $tmp $BinName) `
        -Destination (Join-Path $InstallDir $BinName)

    Write-Host ""
    Write-Host "niro $version installed. Run ``niro init`` to get started."

    # On GitHub Actions, expose the install dir to later workflow steps so
    # `niro ci find` / `niro collect ...` resolve without a PATH edit. Off CI
    # ($env:GITHUB_PATH is unset), persist to the user PATH instead.
    if ($env:GITHUB_PATH) {
        Add-Content -Path $env:GITHUB_PATH -Value $InstallDir
    } else {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($userPath -notlike "*$InstallDir*") {
            [Environment]::SetEnvironmentVariable('Path', "$userPath;$InstallDir", 'User')
            Write-Warn "$InstallDir added to your user PATH. Open a new terminal for the change to take effect."
        }
    }

    # niro spawns pentests inside containers, so it needs Docker,
    # Podman, or nerdctl on PATH. Non-blocking — install has already
    # succeeded. Mirrors the same surface check in install.sh.
    $hasRuntime = (Get-Command docker -ErrorAction SilentlyContinue) `
        -or (Get-Command podman -ErrorAction SilentlyContinue) `
        -or (Get-Command nerdctl -ErrorAction SilentlyContinue)
    if (-not $hasRuntime) {
        Write-Warn "no container runtime found. niro needs Docker, Podman, or nerdctl to run pentests."
        Write-Host "    Docker:  $(Url-Link 'https://docker.com')"
        Write-Host "    Podman:  $(Url-Link 'https://podman.io')"
    }
} finally {
    Remove-Item -Recurse -Force -Path $tmp -ErrorAction SilentlyContinue
}
