# WSL Mac Comfort Shell

You are in a Linux terminal running inside Windows via **WSL**. This repo provides an idempotent bootstrap script and onboarding notes to make that environment feel familiar to macOS developers.

## What this repo includes
- `wsl-mac-comfort-bootstrap.sh`: setup script with WSL checks, apt baseline, optional Homebrew install, zsh managed blocks, and Mac-like helper shims (`pbcopy`, `pbpaste`, `open`)
- `run-in-wsl.ps1`: Windows-side helper that runs the bootstrap script in a target distro from your current repo folder
- `install-terminal-fragment.ps1`: installs a Windows Terminal JSON fragment extension that adds a Mac Comfort profile + color scheme
- `README.md`: onboarding guide and terminal personalization suggestions

## Prereqs
Before running setup:
- WSL installed and working on Windows (`wsl --status`)
- Ubuntu installed in WSL (for example `Ubuntu` or `Ubuntu-24.04`)
- Windows Terminal installed (recommended)
- A user in Ubuntu with sudo access

## Quick start
From inside your Ubuntu WSL shell:

```bash
mkdir -p ~/src
cd ~/src
git clone https://github.com/shanselman/MacLikeWSLComfortShell.git
cd MacLikeWSLComfortShell
chmod +x wsl-mac-comfort-bootstrap.sh
./wsl-mac-comfort-bootstrap.sh
```

If you already downloaded the script elsewhere, copy it into WSL and run it there:

```bash
cp /mnt/c/path/to/wsl-mac-comfort-bootstrap.sh ~/
chmod +x ~/wsl-mac-comfort-bootstrap.sh
~/wsl-mac-comfort-bootstrap.sh
```

## Quick start from a Windows repo clone (run from CWD)
If this repo is cloned on Windows and you are in this folder in PowerShell:

```powershell
wsl --install Ubuntu-24.04 --name MacComfort --no-launch
wsl -d MacComfort   # complete first-launch user creation
.\run-in-wsl.ps1 -Distro MacComfort
```

If you already have a distro:

```powershell
.\run-in-wsl.ps1 -Distro <YourDistroName>
```

Pass bootstrap flags through the wrapper with `-BootstrapArgs`:

```powershell
.\run-in-wsl.ps1 -Distro <YourDistroName> -BootstrapArgs "--dry-run"
.\run-in-wsl.ps1 -Distro <YourDistroName> -BootstrapArgs "--no-brew,--minimal"
```

Then optionally install the Mac Comfort Windows Terminal profile fragment:

```powershell
.\install-terminal-fragment.ps1 -Distro MacComfort
```

For a different distro name:

```powershell
.\install-terminal-fragment.ps1 -Distro <YourDistroName>
```

## Two common scenarios
### 1) New machine (new WSL + Ubuntu)
- Install WSL and Ubuntu.
- Clone this repo (Windows or WSL) and run bootstrap.
- Easiest from Windows clone: `.\run-in-wsl.ps1 -Distro MacComfort`

### 2) Existing WSL distro (existing profiles)
- Run the script in your existing distro; it is designed to be rerun safely.
- It only updates managed blocks in `~/.zprofile` and `~/.zshrc` and avoids overwriting non-managed shim files unless `--force` is used.
- Recommended first run on an existing profile:
  ```bash
  ./wsl-mac-comfort-bootstrap.sh --dry-run
  ./wsl-mac-comfort-bootstrap.sh
  ```
- If you have multiple distros, target one explicitly:
  ```powershell
  wsl -l -q
  wsl -d <DistroName>
  .\run-in-wsl.ps1 -Distro <DistroName> -BootstrapArgs "--dry-run"
  .\run-in-wsl.ps1 -Distro <DistroName>
  ```

## What you get after running bootstrap (default flags)
- **zsh** as your shell (like modern macOS)
- **Homebrew (Linuxbrew)** so `brew install ...` works the way you expect
- **Build essentials**: `build-essential` is installed, giving you `make`, `gcc`, `g++`, and the C standard library headers needed to compile software from source
- A modern CLI toolbox:
  - `git`, `gh`
  - `rg` (ripgrep), `fd`, `bat`, `eza`, `fzf`
  - `jq`, `yq`, `direnv`, `starship` prompt

Notes:
- `--minimal` skips optional extras (for example plugin/tool installs)
- `--no-brew` skips Homebrew install and brew package installs

## Where your files should live
Use the Linux filesystem for coding:
- Put repos in: `~/src`
- Example:
  ```bash
  mkdir -p ~/src
  cd ~/src
  git clone <your-repo>
  ```

You *can* access Windows files at `/mnt/c/...`, but for dev builds and lots of small files it can be slower and sometimes weirder.

## The three commands you will use constantly
- Update packages:
  ```bash
  sudo apt update && sudo apt upgrade
  ```
- Install tools (Mac muscle memory):
  ```bash
  brew install <package>
  ```
- Search like a superhero:
  ```bash
  rg "some text" .
  ```

## Clipboard + "open" helpers (Mac-ish)
These commands behave like on macOS:

- Copy to clipboard:
  ```bash
  pbcopy < file.txt
  echo "hello" | pbcopy
  ```
- Paste from clipboard:
  ```bash
  pbpaste
  ```
- Open a URL in your default Windows browser:
  ```bash
  open https://example.com
  ```

The bootstrap also installs browser opener compatibility (`xdg-open`/`wslview` fallbacks) so tools like `gh auth login` can launch browser sign-in.

## VS Code (recommended workflow)
Best experience is VS Code with Remote WSL.  
From inside WSL, in a repo folder:

```bash
code .
```

That opens VS Code "connected" to Linux so terminals, tools, and paths all match.

## Terminal look and feel (Mac-friendly)
You will use **Windows Terminal** on the Windows side. Open **Settings**, select your **Ubuntu profile**, and apply these profile settings for a Mac-friendly feel:

- **Font face**:
  - `JetBrainsMono Nerd Font` (popular and polished; download: [latest zip](https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip) or [Nerd Fonts downloads](https://www.nerdfonts.com/font-downloads))
  - `Cascadia Mono` (ships with Windows Terminal)
  - `Menlo` or `SF Mono` (if you already have them installed)
- **Font size**: `13` is a great default (`12-14` common)
- **Recommended color scheme**: `One Half Dark`
- **Other good color schemes**: `Solarized Dark` or `Campbell` (default)
- **Cursor shape**: `bar`

To apply these defaults automatically via JSON fragment extension, run:

```powershell
.\install-terminal-fragment.ps1 -Distro <YourDistroName>
```

This writes a fragment file to:
- Current user: `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\MacLikeWSLComfortShell\mac-comfort.fragment.json`
- All users (admin): `C:\ProgramData\Microsoft\Windows Terminal\Fragments\MacLikeWSLComfortShell\mac-comfort.fragment.json` via `-AllUsers`

### Windows Terminal profile snippet
In Windows Terminal settings JSON, profile-level example:

```json
{
  "font": {
    "face": "JetBrainsMono Nerd Font",
    "size": 13
  },
  "colorScheme": "One Half Dark",
  "cursorShape": "bar"
}
```

### Visual walkthrough (Ubuntu profile in Windows Terminal)
Use these in order while updating your Ubuntu profile settings:

1. Open Windows Terminal settings and select the Ubuntu profile  
   ![Windows Terminal Ubuntu profile selection](./img/likemac1.png)

2. Update font and appearance settings for a Mac-like look  
   ![Ubuntu profile appearance settings](./img/likemac2.png)

3. Confirm the profile colors and cursor settings  
   ![Ubuntu profile color and cursor settings](./img/likemac3.png)

## Helpful Mac-style tweaks
- Keep aliases in zsh for `ls`, `ll`, `lt`, `cat`, `grep`, and git shortcuts
- Use `tmux` with `Ctrl+a` prefix for split panes and persistent sessions
- Use `starship` for a clean, fast prompt
- Keep projects in `~/src`, not `/mnt/c/...`, for better performance

## Installing common stuff
Some useful installs:

```bash
brew install node
brew install python
brew install kubectl
brew install terraform
```

If you prefer apt for some things:

```bash
sudo apt install <package>
```

## Quick mental model
- This is **Linux**, not macOS, but it is configured to feel familiar.
- Use `brew` for most developer tools.
- Use `~/src` for code.
- Use `code .` for a smooth editor experience.

## If something feels off
Try:

1. Restart your terminal
2. Confirm shell:
   ```bash
   echo $SHELL
   ```
3. Confirm brew:
   ```bash
   brew --version
   ```

Welcome!
