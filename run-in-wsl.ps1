param(
    [Parameter(Mandatory = $false)]
    [string]$Distro = "MacComfort",

    [Parameter(Mandatory = $false)]
    [string]$BootstrapScript = ".\wsl-mac-comfort-bootstrap.sh",

    [Parameter(Mandatory = $false)]
    [string[]]$BootstrapArgs = @(),

    [Parameter(Mandatory = $false)]
    [switch]$SkipDos2Unix
)

$ErrorActionPreference = "Stop"

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
