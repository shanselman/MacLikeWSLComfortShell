# WSL Mac Comfort Shell

You are in a Linux terminal running inside Windows via **WSL**. This repo provides an idempotent bootstrap script and onboarding notes to make that environment feel familiar to macOS developers.

## What this repo includes
- `wsl-mac-comfort-bootstrap.sh`: setup script with WSL checks, apt baseline, optional Homebrew install, zsh managed blocks, and Mac-like helper shims (`pbcopy`, `pbpaste`, `open`)
- `README.md`: onboarding guide and terminal personalization suggestions

## What you get after running bootstrap (default flags)
- **zsh** as your shell (like modern macOS)
- **Homebrew (Linuxbrew)** so `brew install ...` works the way you expect
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
If you want a Mac-like terminal experience in Windows Terminal, start here:

- **Font face**:
  - `JetBrainsMono Nerd Font` (popular and polished; download: [latest zip](https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip) or [Nerd Fonts downloads](https://www.nerdfonts.com/font-downloads))
  - `Cascadia Mono` (ships with Windows Terminal)
  - `Menlo` or `SF Mono` (if you already have them installed)
- **Font size**: `13` is a great default (`12-14` common)
- **Recommended color scheme**: `One Half Dark`
- **Other good color schemes**: `Solarized Dark` or `Campbell` (default)
- **Cursor shape**: `bar`

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

## Other ideas Mac users usually like
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
