<#
.SYNOPSIS
    Mac my WSL. Agent-friendly orchestration for Mac-like WSL setup.

.DESCRIPTION
    Runs the Linux bootstrap in a target WSL distro and can also apply
    Windows-side comfort steps:
      - Install Windows Terminal profile fragment
      - Add PowerShell keyboard comfort keybindings

    Use -Interactive to answer prompts, save choices as a JSON profile,
    and rerun the same setup later.

.PARAMETER Distro
    Name of the WSL distro to configure.
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
    Skip the automatic CRLF normalization before running the script in WSL.

.PARAMETER Interactive
    Prompt for customization choices and run the full setup pipeline.

.PARAMETER ProfilePath
    Optional JSON profile path. If the file exists, choices are loaded.
    In -Interactive mode, you can choose to save the final selections here.

.PARAMETER InstallTerminalFragment
    Install the Windows Terminal Mac Comfort profile fragment after bootstrap.

.PARAMETER TerminalFragmentAllUsers
    Install the Windows Terminal fragment for all users (requires admin).

.PARAMETER ConfigurePowerShellKeyboard
    Add PSReadLine keybindings to the PowerShell profile:
      Alt+Backspace -> BackwardKillWord
      Ctrl+u        -> BackwardKillLine

.EXAMPLE
    .\mac-my-wsl.ps1 -Interactive

.EXAMPLE
    .\mac-my-wsl.ps1 -Distro Ubuntu -BootstrapArgs "--dry-run"

.EXAMPLE
    .\mac-my-wsl.ps1 -ProfilePath .\profiles\my-setup.json

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
    [switch]$SkipDos2Unix,

    [Parameter(Mandatory = $false)]
    [switch]$Interactive,

    [Parameter(Mandatory = $false)]
    [string]$ProfilePath,

    [Parameter(Mandatory = $false)]
    [switch]$InstallTerminalFragment,

    [Parameter(Mandatory = $false)]
    [switch]$TerminalFragmentAllUsers,

    [Parameter(Mandatory = $false)]
    [switch]$ConfigurePowerShellKeyboard
)

$ErrorActionPreference = "Stop"

function Quote-BashArg {
    param([Parameter(Mandatory = $true)][string]$Value)
    return "'" + ($Value -replace "'", "'""'""'") + "'"
}

function Convert-WindowsPathToWslPath {
    param([Parameter(Mandatory = $true)][string]$WindowsPath)

    if ($WindowsPath -match '^[A-Za-z]:\\') {
        $drive = $WindowsPath.Substring(0, 1).ToLowerInvariant()
        $rest = $WindowsPath.Substring(2) -replace '\\', '/'
        return "/mnt/$drive$rest"
    }

    throw "Unsupported path format for WSL path conversion: $WindowsPath"
}

function Get-InstalledDistros {
    $rows = @(wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    return @($rows)
}

function Normalize-BootstrapArgs {
    param([string[]]$ArgsInput)

    $normalized = @()
    foreach ($arg in $ArgsInput) {
        if ([string]::IsNullOrWhiteSpace($arg)) {
            continue
        }
        $normalized += @($arg -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    return @($normalized | Select-Object -Unique)
}

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][bool]$Default
    )

    $hint = if ($Default) { "[Y/n]" } else { "[y/N]" }
    while ($true) {
        $value = (Read-Host "$Prompt $hint").Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $Default
        }
        switch -Regex ($value) {
            '^(y|yes)$' { return $true }
            '^(n|no)$' { return $false }
            default { Write-Host "Please enter y or n." -ForegroundColor Yellow }
        }
    }
}

function Load-ProfileConfig {
    param([Parameter(Mandatory = $true)][string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw
    $obj = $raw | ConvertFrom-Json

    $result = @{
        Distro                    = $null
        BootstrapArgs             = @()
        SkipDos2Unix              = $false
        InstallTerminalFragment   = $false
        TerminalFragmentAllUsers  = $false
        ConfigurePowerShellKeyboard = $false
    }

    if ($obj.PSObject.Properties.Name -contains "distro" -and $obj.distro) {
        $result.Distro = [string]$obj.distro
    }
    if ($obj.PSObject.Properties.Name -contains "bootstrapArgs" -and $obj.bootstrapArgs) {
        $result.BootstrapArgs = @($obj.bootstrapArgs | ForEach-Object { [string]$_ })
    }
    if ($obj.PSObject.Properties.Name -contains "skipDos2Unix") {
        $result.SkipDos2Unix = [bool]$obj.skipDos2Unix
    }
    if ($obj.PSObject.Properties.Name -contains "installTerminalFragment") {
        $result.InstallTerminalFragment = [bool]$obj.installTerminalFragment
    }
    if ($obj.PSObject.Properties.Name -contains "terminalFragmentAllUsers") {
        $result.TerminalFragmentAllUsers = [bool]$obj.terminalFragmentAllUsers
    }
    if ($obj.PSObject.Properties.Name -contains "configurePowerShellKeyboard") {
        $result.ConfigurePowerShellKeyboard = [bool]$obj.configurePowerShellKeyboard
    }

    return $result
}

function Save-ProfileConfig {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Config
    )

    $payload = [ordered]@{
        distro                     = $Config.Distro
        bootstrapArgs              = @($Config.BootstrapArgs)
        skipDos2Unix               = [bool]$Config.SkipDos2Unix
        installTerminalFragment    = [bool]$Config.InstallTerminalFragment
        terminalFragmentAllUsers   = [bool]$Config.TerminalFragmentAllUsers
        configurePowerShellKeyboard = [bool]$Config.ConfigurePowerShellKeyboard
    }

    $targetPath = [System.IO.Path]::GetFullPath($Path)
    $targetDir = Split-Path -Parent $targetPath
    if ($targetDir -and -not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $targetPath -Encoding UTF8
    Write-Host "Saved profile: $targetPath" -ForegroundColor Green
}

function Update-ManagedBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $start = "# >>> $Marker >>>"
    $end = "# <<< $Marker <<<"
    $block = "$start`r`n$Content`r`n$end"

    if (-not (Test-Path -LiteralPath $Path)) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $Path -Value "" -Encoding UTF8
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    $pattern = "(?ms)^\Q$start\E\r?\n.*?^\Q$end\E\r?\n?"
    $withoutBlock = [regex]::Replace($raw, $pattern, "")
    $trimmed = $withoutBlock.TrimEnd("`r", "`n")

    $newRaw = if ([string]::IsNullOrWhiteSpace($trimmed)) {
        "$block`r`n"
    } else {
        "$trimmed`r`n`r`n$block`r`n"
    }

    Set-Content -LiteralPath $Path -Value $newRaw -Encoding UTF8
}

function Configure-PowerShellKeyboardComfort {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $content = @'
if (Get-Module -ListAvailable -Name PSReadLine) {
    Set-PSReadLineKeyHandler -Chord Alt+Backspace -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardKillLine
}
'@
    Update-ManagedBlock -Path $profilePath -Marker "mac-keyboard-comfort" -Content $content
    Write-Host "Updated keyboard comfort bindings in $profilePath" -ForegroundColor Green
}

function Invoke-Bootstrap {
    param(
        [Parameter(Mandatory = $true)][string]$TargetDistro,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string[]]$NormalizedArgs,
        [Parameter(Mandatory = $true)][bool]$SkipNormalization
    )

    $bootstrapScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path
    $bootstrapScriptWslPath = Convert-WindowsPathToWslPath -WindowsPath $bootstrapScriptPath
    $quotedScriptPath = Quote-BashArg $bootstrapScriptWslPath
    $quotedArgs = @($NormalizedArgs | ForEach-Object { Quote-BashArg $_ }) -join " "
    $normalizeStep = if ($SkipNormalization) { "" } else { "sed -i 's/\r$//' ~/wsl-mac-comfort-bootstrap.sh && " }

    $bashCommand = "set -euo pipefail; cp $quotedScriptPath ~/wsl-mac-comfort-bootstrap.sh && ${normalizeStep}chmod +x ~/wsl-mac-comfort-bootstrap.sh && ~/wsl-mac-comfort-bootstrap.sh"
    if ($quotedArgs) {
        $bashCommand = "$bashCommand $quotedArgs"
    }

    Write-Host "Running bootstrap in distro '$TargetDistro'..." -ForegroundColor Cyan
    wsl -d $TargetDistro -- bash -lc "$bashCommand"
}

function Invoke-TerminalFragmentInstall {
    param(
        [Parameter(Mandatory = $true)][string]$TargetDistro,
        [Parameter(Mandatory = $true)][bool]$AllUsers
    )

    $installerPath = Join-Path $PSScriptRoot "install-terminal-fragment.ps1"
    if (-not (Test-Path -LiteralPath $installerPath)) {
        throw "Missing script: $installerPath"
    }

    $params = @{
        Distro = $TargetDistro
    }
    if ($AllUsers) {
        $params.AllUsers = $true
    }

    & $installerPath @params
}

function Get-FlagState {
    param(
        [Parameter(Mandatory = $true)][string[]]$ArgsList,
        [Parameter(Mandatory = $true)][string]$Flag
    )
    return ($ArgsList -contains $Flag)
}

$config = @{
    Distro                      = $null
    BootstrapArgs               = @()
    SkipDos2Unix                = $false
    InstallTerminalFragment     = $false
    TerminalFragmentAllUsers    = $false
    ConfigurePowerShellKeyboard = $false
}

if ($ProfilePath) {
    if (Test-Path -LiteralPath $ProfilePath) {
        Write-Host "Loading profile: $ProfilePath" -ForegroundColor Cyan
        $loaded = Load-ProfileConfig -Path $ProfilePath
        $config.Distro = $loaded.Distro
        $config.BootstrapArgs = Normalize-BootstrapArgs -ArgsInput $loaded.BootstrapArgs
        $config.SkipDos2Unix = [bool]$loaded.SkipDos2Unix
        $config.InstallTerminalFragment = [bool]$loaded.InstallTerminalFragment
        $config.TerminalFragmentAllUsers = [bool]$loaded.TerminalFragmentAllUsers
        $config.ConfigurePowerShellKeyboard = [bool]$loaded.ConfigurePowerShellKeyboard
    } elseif (-not $Interactive) {
        throw "Profile not found: $ProfilePath"
    }
}

if ($PSBoundParameters.ContainsKey("Distro")) {
    $config.Distro = $Distro
}

$cliBootstrapArgs = Normalize-BootstrapArgs -ArgsInput $BootstrapArgs
if ($cliBootstrapArgs.Count -gt 0) {
    $config.BootstrapArgs = @($config.BootstrapArgs + $cliBootstrapArgs | Select-Object -Unique)
}

if ($SkipDos2Unix) {
    $config.SkipDos2Unix = $true
}
if ($InstallTerminalFragment) {
    $config.InstallTerminalFragment = $true
}
if ($TerminalFragmentAllUsers) {
    $config.InstallTerminalFragment = $true
    $config.TerminalFragmentAllUsers = $true
}
if ($ConfigurePowerShellKeyboard) {
    $config.ConfigurePowerShellKeyboard = $true
}

if ($Interactive) {
    $distros = Get-InstalledDistros
    if ($distros.Count -eq 0) {
        throw "No WSL distros found. Install one first (e.g. wsl --install Ubuntu-24.04)."
    }

    Write-Host ""
    Write-Host "Available WSL distros:" -ForegroundColor Cyan
    foreach ($name in $distros) {
        Write-Host "  - $name"
    }
    $defaultDistro = if ($config.Distro -and ($distros -contains $config.Distro)) {
        $config.Distro
    } elseif ($distros -contains "MacComfort") {
        "MacComfort"
    } else {
        $distros[0]
    }

    while ($true) {
        $picked = (Read-Host "WSL distro to configure [$defaultDistro]").Trim()
        if ([string]::IsNullOrWhiteSpace($picked)) {
            $picked = $defaultDistro
        }
        if ($distros -contains $picked) {
            $config.Distro = $picked
            break
        }
        Write-Host "Distro '$picked' was not found in 'wsl -l -q' output." -ForegroundColor Yellow
    }

    $knownFlags = @("--dry-run", "--minimal", "--no-brew", "--force")
    $extraFlags = @($config.BootstrapArgs | Where-Object { $_ -notin $knownFlags })
    $dryRun = Read-YesNo -Prompt "Run bootstrap in dry-run mode first?" -Default (Get-FlagState -ArgsList $config.BootstrapArgs -Flag "--dry-run")
    $minimal = Read-YesNo -Prompt "Use minimal install (skip optional extras)?" -Default (Get-FlagState -ArgsList $config.BootstrapArgs -Flag "--minimal")
    $noBrew = Read-YesNo -Prompt "Skip Homebrew install?" -Default (Get-FlagState -ArgsList $config.BootstrapArgs -Flag "--no-brew")
    $force = Read-YesNo -Prompt "Force overwrite managed-compatible files?" -Default (Get-FlagState -ArgsList $config.BootstrapArgs -Flag "--force")

    $newFlags = @()
    if ($dryRun) { $newFlags += "--dry-run" }
    if ($minimal) { $newFlags += "--minimal" }
    if ($noBrew) { $newFlags += "--no-brew" }
    if ($force) { $newFlags += "--force" }
    $config.BootstrapArgs = @($newFlags + $extraFlags | Select-Object -Unique)

    $config.SkipDos2Unix = Read-YesNo -Prompt "Skip CRLF normalization before running script in WSL?" -Default $config.SkipDos2Unix
    $config.InstallTerminalFragment = Read-YesNo -Prompt "Install Windows Terminal Mac Comfort profile fragment?" -Default $config.InstallTerminalFragment
    if ($config.InstallTerminalFragment) {
        $config.TerminalFragmentAllUsers = Read-YesNo -Prompt "Install terminal fragment for all users (requires admin)?" -Default $config.TerminalFragmentAllUsers
    } else {
        $config.TerminalFragmentAllUsers = $false
    }
    $config.ConfigurePowerShellKeyboard = Read-YesNo -Prompt "Configure PowerShell keyboard comforts?" -Default $config.ConfigurePowerShellKeyboard

    if (Read-YesNo -Prompt "Save these choices to a profile JSON for reuse?" -Default ([bool]$ProfilePath)) {
        $defaultProfilePath = if ($ProfilePath) { $ProfilePath } else { ".\profiles\mac-my-wsl.$($config.Distro).json" }
        $profileSavePath = (Read-Host "Profile path [$defaultProfilePath]").Trim()
        if ([string]::IsNullOrWhiteSpace($profileSavePath)) {
            $profileSavePath = $defaultProfilePath
        }
        Save-ProfileConfig -Path $profileSavePath -Config $config
    }
}

if (-not $config.Distro) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

$distroList = Get-InstalledDistros
if (-not ($distroList -contains $config.Distro)) {
    throw "WSL distro '$($config.Distro)' not found. Run 'wsl -l -q' to list available distros."
}

$config.BootstrapArgs = Normalize-BootstrapArgs -ArgsInput $config.BootstrapArgs
Invoke-Bootstrap -TargetDistro $config.Distro -ScriptPath $BootstrapScript -NormalizedArgs $config.BootstrapArgs -SkipNormalization $config.SkipDos2Unix

$dryRunMode = $config.BootstrapArgs -contains "--dry-run"
if ($dryRunMode) {
    Write-Host "Bootstrap ran with --dry-run, so Windows-side customization steps were skipped." -ForegroundColor Yellow
} else {
    if ($config.InstallTerminalFragment) {
        Invoke-TerminalFragmentInstall -TargetDistro $config.Distro -AllUsers $config.TerminalFragmentAllUsers
    }
    if ($config.ConfigurePowerShellKeyboard) {
        Configure-PowerShellKeyboardComfort
    }
}

Write-Host ""
Write-Host "Mac my WSL complete." -ForegroundColor Green
Write-Host "Summary:"
Write-Host "  Distro: $($config.Distro)"
Write-Host "  Bootstrap args: $(@($config.BootstrapArgs) -join ' ')"
Write-Host "  Skip DOS->Unix normalization: $($config.SkipDos2Unix)"
Write-Host "  Install Windows Terminal fragment: $($config.InstallTerminalFragment)"
Write-Host "  Terminal fragment all users: $($config.TerminalFragmentAllUsers)"
Write-Host "  Configure PowerShell keyboard comforts: $($config.ConfigurePowerShellKeyboard)"
