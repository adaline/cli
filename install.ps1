#Requires -Version 5.0
<#
.SYNOPSIS
    Adaline CLI installer for Windows.

.DESCRIPTION
    Downloads a standalone `adaline.exe` (no Node.js required) from GitHub
    Releases, verifies its checksum, installs it under %LOCALAPPDATA%, and adds
    it to the user PATH.

    Install the latest version:
        powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/adaline/cli/main/install.ps1 | iex"

    Environment overrides:
        ADALINE_VERSION       version/tag to install (default: latest)
        ADALINE_INSTALL_DIR   install directory (default: %LOCALAPPDATA%\Adaline\bin)
        ADALINE_REPO          owner/repo to download from (default: adaline/cli)
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- configuration -----------------------------------------------------------
$Repo       = if ($env:ADALINE_REPO) { $env:ADALINE_REPO } else { 'adaline/cli' }
$BinName    = 'adaline'
$AliasName  = 'adx'
$InstallDir = if ($env:ADALINE_INSTALL_DIR) { $env:ADALINE_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Adaline\bin' }

function Write-Info { param($m) Write-Host $m }
function Write-Warn { param($m) Write-Host $m -ForegroundColor Yellow }
function Fail       { param($m) Write-Host "error: $m" -ForegroundColor Red; exit 1 }

# TLS 1.2 for older PowerShell/.NET defaults; harmless on newer ones.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# --- detect platform ---------------------------------------------------------
# Bun ships a Windows x64 build; arm64 Windows runs it under emulation.
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -ne 'AMD64' -and $arch -ne 'ARM64') {
    Fail "unsupported architecture '$arch' - see https://github.com/$Repo/releases for available binaries"
}
$asset = "$BinName-windows-x64.exe"

# --- resolve download URLs ---------------------------------------------------
$version = if ($env:ADALINE_VERSION) { $env:ADALINE_VERSION } else { 'latest' }
if ($version -eq 'latest') {
    $base  = "https://github.com/$Repo/releases/latest/download"
    $label = 'latest'
} else {
    # Accept "1.2.3", "v1.2.3", or "cli-v1.2.3"; releases are tagged "cli-v<version>".
    if     ($version -like 'cli-v*') { $tag = $version }
    elseif ($version -like 'v*')     { $tag = "cli-$version" }
    else                             { $tag = "cli-v$version" }
    $base  = "https://github.com/$Repo/releases/download/$tag"
    $label = $tag
}
$assetUrl = "$base/$asset"
$sumsUrl  = "$base/SHA256SUMS"

Write-Info "Installing $BinName (windows/x64, $label)"

# --- download into a temp file ----------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("adaline-" + [System.Guid]::NewGuid().ToString('N'))
$tmpBin = "$tmp.exe"
try {
    Write-Info "Downloading $assetUrl"
    try {
        Invoke-WebRequest -Uri $assetUrl -OutFile $tmpBin -UseBasicParsing
    } catch {
        Fail "download failed - is '$label' a published release? ($($_.Exception.Message))"
    }

    # --- verify checksum (best-effort) ---------------------------------------
    try {
        $sums = (Invoke-WebRequest -Uri $sumsUrl -UseBasicParsing).Content
        $expected = $null
        foreach ($line in $sums -split "`n") {
            $parts = ($line.Trim() -split '\s+', 2)
            if ($parts.Count -eq 2 -and $parts[1] -eq $asset) { $expected = $parts[0].ToLower() }
        }
        if ($expected) {
            $actual = (Get-FileHash -Path $tmpBin -Algorithm SHA256).Hash.ToLower()
            if ($actual -ne $expected) { Fail "checksum mismatch for $asset (expected $expected, got $actual)" }
            Write-Info "checksum verified"
        } else {
            Write-Warn "could not fetch checksum for $asset - skipping verification"
        }
    } catch {
        Write-Warn "could not verify checksum - skipping verification"
    }

    # --- install -------------------------------------------------------------
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
    $dest = Join-Path $InstallDir "$BinName.exe"
    Move-Item -Force -Path $tmpBin -Destination $dest

    # Install the short `adx` alias alongside `adaline`. Windows symlinks need
    # elevation/Developer Mode, so a plain copy is the reliable choice here.
    $aliasDest = Join-Path $InstallDir "$AliasName.exe"
    Copy-Item -Force -Path $dest -Destination $aliasDest

    $installedVersion = ''
    try { $installedVersion = (& $dest --version) 2>$null } catch {}
    Write-Info "installed $BinName $installedVersion -> $dest"
    Write-Info "  also available as $AliasName"
} finally {
    if (Test-Path $tmpBin) { Remove-Item -Force $tmpBin -ErrorAction SilentlyContinue }
}

# --- add to user PATH --------------------------------------------------------
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$onPath = $false
if ($userPath) {
    foreach ($p in $userPath -split ';') { if ($p.TrimEnd('\') -ieq $InstallDir.TrimEnd('\')) { $onPath = $true } }
}
if (-not $onPath) {
    $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    # Update the current session too so the user can run it without reopening.
    $env:Path = "$env:Path;$InstallDir"
    Write-Info ""
    Write-Info "Added $InstallDir to your user PATH."
    Write-Warn "Open a NEW terminal for the PATH change to take effect everywhere."
}

Write-Info ""
Write-Info "Run '$BinName --help' to get started."
