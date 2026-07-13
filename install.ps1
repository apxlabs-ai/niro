# Niro installer for Windows (PowerShell).
#
# Usage:
#   irm https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.ps1 | iex
#
# Environment variables:
#   NIRO_VERSION       Pin an exact stable, dev, or RC tag (e.g. v0.1.0).
#   NIRO_CHANNEL       Select stable, dev, or rc. Defaults to stable.
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

function Test-ReleaseTag($tag) {
    $tag -match '^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-(dev|rc)\.(0|[1-9]\d*))?$'
}

function Test-ChannelTag($tag, $channel) {
    if ($tag -notmatch '^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)-(?<channel>dev|rc)\.(0|[1-9]\d*)$') {
        return $false
    }
    $matches['channel'] -eq $channel
}

function Get-ReleasePage($uri) {
    Invoke-RestMethod -Uri $uri -Headers @{
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
}

function Resolve-Channel($channel) {
    if ($channel -eq 'stable') {
        try {
            $response = Invoke-WebRequest -Uri "https://github.com/$Repo/releases/latest" -UseBasicParsing
            $resolvedUri = if ($response.BaseResponse.ResponseUri) {
                $response.BaseResponse.ResponseUri.AbsoluteUri
            } elseif ($response.BaseResponse.RequestMessage.RequestUri) {
                $response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
            } else {
                $null
            }
        } catch {
            throw "could not resolve the stable release channel: $_"
        }
        if ($resolvedUri -notmatch '/releases/tag/([^/]+)$') {
            throw 'no published stable release found'
        }
        $tag = $matches[1]
        if (-not (Test-ReleaseTag $tag) -or $tag -match '-') {
            throw 'no published stable release found'
        }
        return $tag
    }

    $page = 1
    $bestRelease = $null
    $bestPublishedAt = $null
    while ($true) {
        try {
            $releases = @(Get-ReleasePage "https://api.github.com/repos/$Repo/releases?per_page=100&page=$page")
        } catch {
            throw "could not resolve the $channel release channel: $_"
        }
        foreach ($release in $releases |
            Where-Object { -not $_.draft -and $_.prerelease -and (Test-ChannelTag $_.tag_name $channel) }) {
            if (-not $release.published_at) { continue }
            $publishedAt = [DateTimeOffset]$release.published_at
            if (-not $bestRelease -or $publishedAt -gt $bestPublishedAt) {
                $bestRelease = $release
                $bestPublishedAt = $publishedAt
            }
        }
        if ($releases.Count -lt 100) { break }
        $page++
    }
    if ($bestRelease) { return $bestRelease.tag_name }
    throw "no published $channel prerelease found"
}

$versionSelector = $env:NIRO_VERSION
$channelSelector = $env:NIRO_CHANNEL
if ($versionSelector -and $channelSelector) {
    throw 'NIRO_VERSION and NIRO_CHANNEL cannot both be set'
}

if ($versionSelector) {
    if (-not (Test-ReleaseTag $versionSelector)) {
        throw 'NIRO_VERSION must match vX.Y.Z, vX.Y.Z-dev.N, or vX.Y.Z-rc.N'
    }
    $version = $versionSelector
} else {
    if (-not $channelSelector) { $channelSelector = 'stable' }
    if ($channelSelector -notin @('stable', 'dev', 'rc')) {
        throw "unknown NIRO_CHANNEL: $channelSelector (expected stable, dev, or rc)"
    }
    $version = Resolve-Channel $channelSelector
}

Write-Host "Resolved niro release: $version"
$archive = "niro_windows_${arch}.zip"
$baseUrl = "https://github.com/$Repo/releases/download/$version"

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
    # `niro find` / `niro collect ...` resolve without a PATH edit. Off CI
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
