# WSL Mac Comfort Shell

Make WSL on Windows feel familiar to macOS developers.

## Give this to your agent

Use this repo as an automation tool.

1. Open `feed-this-to-your-agent.md`.
2. Paste it into your coding agent.
3. Let the agent ask your preferences and run the setup.

Fast path:

```powershell
.\mac-my-wsl.ps1 -Interactive
```

## Details for humans

### What is in this repo

- `mac-my-wsl.ps1` - Windows-side orchestrator (interactive + profile-driven).
- `wsl-mac-comfort-bootstrap.sh` - Linux bootstrap for WSL distro setup.
- `install-terminal-fragment.ps1` - Windows Terminal profile fragment installer.
- `feed-this-to-your-agent.md` - Copy/paste instructions for agents.

### Manual usage (no agent)

```powershell
wsl -l -q
.\mac-my-wsl.ps1 -Distro <YourDistroName>
```

Preview first:

```powershell
.\mac-my-wsl.ps1 -Distro <YourDistroName> -BootstrapArgs "--dry-run"
```

Apply Windows-side options too:

```powershell
.\mac-my-wsl.ps1 -Distro <YourDistroName> `
  -InstallTerminalFragment `
  -ConfigurePowerShellKeyboard
```

### Visual walkthrough (Windows Terminal profile)

1. Open Windows Terminal settings and select your Ubuntu profile.  
   ![Windows Terminal Ubuntu profile selection](./img/likemac1.png)

2. Update font and appearance settings for a Mac-like look.  
   ![Ubuntu profile appearance settings](./img/likemac2.png)

3. Confirm profile colors and cursor settings.  
   ![Ubuntu profile color and cursor settings](./img/likemac3.png)

### Reusable profiles

Create/save with interactive mode:

```powershell
.\mac-my-wsl.ps1 -Interactive -ProfilePath .\profiles\my-setup.json
```

Reuse later:

```powershell
.\mac-my-wsl.ps1 -ProfilePath .\profiles\my-setup.json
```

### Bootstrap flags

Pass through with `-BootstrapArgs`:

- `--dry-run`
- `--minimal`
- `--no-brew`
- `--force`

Example:

```powershell
.\mac-my-wsl.ps1 -Distro <YourDistroName> -BootstrapArgs "--minimal,--no-brew"
```

### Keyboard comforts

PowerShell (added by `-ConfigurePowerShellKeyboard`):

```powershell
Set-PSReadLineKeyHandler -Chord Alt+Backspace -Function BackwardKillWord
Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardKillLine
```

- `Alt+Backspace` -> delete previous word
- `Ctrl+u` -> clear line to the left
- `Ctrl+Backspace` -> delete previous word (already default)

Note: `Win+Backspace` is handled by Windows before shells receive it. If you want Cmd-like behavior from a Mac keyboard, use PowerToys Keyboard Manager to remap keys.

![PowerToys Keyboard Manager remapping view](./img/keyboardmanager.png)

### Troubleshooting

- Slow typing in zsh often comes from `zsh-syntax-highlighting`.
- Try bootstrap with `--minimal` to skip extra plugins.
- Keep repos in `~/src` (inside Linux filesystem) for better performance.

### Prereqs

- WSL installed and working (`wsl --status`)
- Ubuntu or Debian distro installed
- Windows Terminal (recommended)
- User in distro with sudo access
