# Welcome to WSL (Mac-style)

You're in a Linux terminal running inside Windows via **WSL**. This environment is set up to feel familiar if you're coming from macOS.

## What you have by default
- **zsh** as your shell (like modern macOS)
- **Homebrew (Linuxbrew)** so `brew install ...` works the way you expect
- A modern CLI toolbox:
  - `git`, `gh`
  - `rg` (ripgrep), `fd`, `bat`, `eza`, `fzf`
  - `jq`, `yq`, `direnv`, `starship` prompt

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

## The three commands you'll use constantly
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

## VS Code (recommended workflow)
Best experience is VS Code with Remote WSL.  
From inside WSL, in a repo folder:

```bash
code .
```

That opens VS Code "connected" to Linux so terminals, tools, and paths all match.

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
- This is **Linux**, not macOS, but it's configured to feel familiar.
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
