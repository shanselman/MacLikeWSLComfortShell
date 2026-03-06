<#
.SYNOPSIS
    Mac my WSL! Makes a WSL Ubuntu/Debian distro feel like macOS.

.DESCRIPTION
    Copies the bootstrap script into the target WSL distro and runs it.
    The bootstrap installs zsh, Homebrew, modern CLI tools (ripgrep, bat,
    eza, fzf, starship, etc.), Mac-like shims (pbcopy, pbpaste, open),
    and configures .zprofile/.zshrc with sensible defaults.

    The script is idempotent — safe to run repeatedly on the same distro.

.PARAMETER Distro
    Name of the WSL distro to configure. Required.
    Run 'wsl -l -q' to list available distros.

.PARAMETER BootstrapScript
    Path to the bootstrap shell script on the Windows side.
    Defaults to .\wsl-mac-comfort-bootstrap.sh in the current directory.

.PARAMETER BootstrapArgs
    Flags forwarded to the bootstrap script inside WSL.
    Comma-separate multiple flags or pass them as an array.
      --dry-run   Show what would happen without making changes.
      --minimal   Skip optional extras (brew formulae and zsh plugins).
      --no-brew   Skip Homebrew install and brew package installs.
      --force     Overwrite managed files and existing shims.

.PARAMETER SkipDos2Unix
    Skip the automatic Windows line-ending fix (sed CR strip) before
    running the bootstrap script. Use this if you know the script already
    has Unix line endings.

.EXAMPLE
    # Brand-new distro — install and configure from scratch
    wsl --install Ubuntu-24.04 --name MacComfort --no-launch
    wsl -d MacComfort          # complete first-launch user creation
    .\mac-my-wsl.ps1 -Distro MacComfort

.EXAMPLE
    # Existing distro — preview changes first, then apply
    .\mac-my-wsl.ps1 -Distro Ubuntu -BootstrapArgs "--dry-run"
    .\mac-my-wsl.ps1 -Distro Ubuntu

.EXAMPLE
    # Lightweight setup — skip Homebrew and optional extras
    .\mac-my-wsl.ps1 -Distro MyDistro -BootstrapArgs "--no-brew,--minimal"

.LINK
    https://github.com/shanselman/MacLikeWSLComfortShell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Distro,

    [Parameter(Mandatory = $false)]
    [string]$BootstrapScript = ".\wsl-mac-comfort-bootstrap.sh",

    [Parameter(Mandatory = $false)]
    [string[]]$BootstrapArgs = @(),

    [Parameter(Mandatory = $false)]
    [switch]$SkipDos2Unix
)

$ErrorActionPreference = "Stop"

if (-not $Distro) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

function Quote-BashArg {
    param([string]$Value)
    return "'" + ($Value -replace "'", "'""'""'") + "'"
}

function Convert-WindowsPathToWslPath {
    param([string]$WindowsPath)

    if ($WindowsPath -match '^[A-Za-z]:\\') {
        $drive = $WindowsPath.Substring(0, 1).ToLowerInvariant()
        $rest = $WindowsPath.Substring(2) -replace '\\', '/'
        return "/mnt/$drive$rest"
    }

    throw "Unsupported script path format for WSL path conversion: $WindowsPath"
}

$bootstrapScriptPath = (Resolve-Path -LiteralPath $BootstrapScript).Path
$distroList = @(wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })

if (-not ($distroList -contains $Distro)) {
    throw "WSL distro '$Distro' not found. Run 'wsl -l -q' to list available distros."
}

$bootstrapScriptWslPath = Convert-WindowsPathToWslPath -WindowsPath $bootstrapScriptPath

$quotedScriptPath = Quote-BashArg $bootstrapScriptWslPath
$normalizedBootstrapArgs = @()
foreach ($arg in $BootstrapArgs) {
    if ([string]::IsNullOrWhiteSpace($arg)) {
        continue
    }
    $normalizedBootstrapArgs += @($arg -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
$quotedArgs = @($normalizedBootstrapArgs | ForEach-Object { Quote-BashArg $_ }) -join " "
$normalizeStep = if ($SkipDos2Unix) { "" } else { "sed -i 's/\r$//' ~/wsl-mac-comfort-bootstrap.sh && " }

$bashCommand = "set -euo pipefail; cp $quotedScriptPath ~/wsl-mac-comfort-bootstrap.sh && ${normalizeStep}chmod +x ~/wsl-mac-comfort-bootstrap.sh && ~/wsl-mac-comfort-bootstrap.sh"
if ($quotedArgs) {
    $bashCommand = "$bashCommand $quotedArgs"
}

Write-Host "Running bootstrap in distro '$Distro'..." -ForegroundColor Cyan
wsl -d $Distro -- bash -lc "$bashCommand"
