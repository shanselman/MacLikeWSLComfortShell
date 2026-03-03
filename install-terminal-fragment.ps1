param(
    [Parameter(Mandatory = $false)]
    [string]$Distro = "MacComfort",

    [Parameter(Mandatory = $false)]
    [string]$AppName = "MacLikeWSLComfortShell",

    [Parameter(Mandatory = $false)]
    [switch]$AllUsers
)

$ErrorActionPreference = "Stop"

if ($AllUsers) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "AllUsers mode requires an elevated PowerShell session."
    }
}

$fragmentsRoot = if ($AllUsers) {
    Join-Path $env:ProgramData "Microsoft\Windows Terminal\Fragments"
} else {
    Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments"
}

$targetDir = Join-Path $fragmentsRoot $AppName
$targetFile = Join-Path $targetDir "mac-comfort.fragment.json"
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

$fragment = @{
    profiles = @(
        @{
            guid = "{3f337f9d-95f2-4e3d-b8f4-6f9227696af0}"
            name = "Mac Comfort Shell 🍎"
            commandline = "wsl.exe -d $Distro"
            startingDirectory = "~"
            colorScheme = "Mac Comfort Dark"
            cursorShape = "bar"
            hidden = $false
            font = @{
                face = "JetBrainsMono Nerd Font"
                size = 13
            }
        }
    )
    schemes = @(
        @{
            name = "Mac Comfort Dark"
            background = "#282C34"
            foreground = "#DCDFE4"
            cursorColor = "#98C379"
            selectionBackground = "#3E4452"
            black = "#282C34"
            red = "#E06C75"
            green = "#98C379"
            yellow = "#E5C07B"
            blue = "#61AFEF"
            purple = "#C678DD"
            cyan = "#56B6C2"
            white = "#DCDFE4"
            brightBlack = "#5A6374"
            brightRed = "#E06C75"
            brightGreen = "#98C379"
            brightYellow = "#E5C07B"
            brightBlue = "#61AFEF"
            brightPurple = "#C678DD"
            brightCyan = "#56B6C2"
            brightWhite = "#FFFFFF"
        }
    )
}

$fragment | ConvertTo-Json -Depth 8 | Out-File -FilePath $targetFile -Encoding Utf8

Write-Host "Installed Windows Terminal fragment:" -ForegroundColor Green
Write-Host "  $targetFile"
Write-Host ""
Write-Host "Profile name: Mac Comfort Shell 🍎"
Write-Host "Distro target: $Distro"
Write-Host ""
Write-Host "Restart Windows Terminal to load the new profile."
