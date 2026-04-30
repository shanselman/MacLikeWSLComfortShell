# Give this to your agent

You are setting up a Windows + WSL machine so it feels like macOS for development.

Use this repository as an execution tool, not as a checklist:
- `mac-my-wsl.ps1` orchestrates setup and optional customizations.
- `wsl-mac-comfort-bootstrap.sh` configures the Linux side.
- `install-terminal-fragment.ps1` configures Windows Terminal profile defaults.

## Prerequisites

Before running anything, verify:
- **WSL distro exists**: Run `wsl -l -q` and confirm the target distro is listed. If not, install it with `wsl --install -d <DistroName>`.
- **Distro user is set up**: A fresh distro needs initial launch to create the default user. Run `wsl -d <DistroName> -- echo ready` to confirm.
- **Sudo access**: The target user must have passwordless sudo, or the bootstrap must run as root with `--user <username>`. Without this, the script will fail immediately (it will not hang waiting for a password).
- **Nerd Font**: The terminal profile uses JetBrainsMono Nerd Font. Check if it's installed; if not, suggest `winget install JanDeDobbeleer.OhMyPosh` or download from nerdfonts.com.

## What to do

1. Ask the customer these questions before running anything:
   - Which WSL distro should be configured?
   - Do they want a dry run first?
   - Minimal setup or full setup?
   - Should Homebrew be skipped?
   - Should Windows Terminal profile fragment be installed?
   - Should PowerShell keyboard comforts be configured (Alt+Backspace, Ctrl+U)?

2. If they want a guided flow, run:
   ```powershell
   .\mac-my-wsl.ps1 -Interactive
   ```

3. If they want a repeatable run profile, save and reuse:
   ```powershell
   .\mac-my-wsl.ps1 -Interactive -ProfilePath .\profiles\customer.json
   .\mac-my-wsl.ps1 -ProfilePath .\profiles\customer.json
   ```

4. If they want explicit non-interactive execution, run:
   ```powershell
   .\mac-my-wsl.ps1 -Distro <DistroName> -BootstrapArgs "--dry-run,--minimal"
   ```
   and include optional flags as requested:
   - `-InstallTerminalFragment`
   - `-TerminalFragmentAllUsers`
   - `-ConfigurePowerShellKeyboard`
   - `-SkipDos2Unix`

5. Report exactly what changed and what was skipped.

## Running as root vs as the target user

- **Preferred**: Run the bootstrap as the actual target user (e.g. `wsl -d Ubuntu -u scott`). This avoids ownership issues and allows Homebrew to install correctly.
- **If running as root**: Pass `--user <username>` to the bootstrap so dotfiles, shims, and configs are written to the correct home directory. Note that **Homebrew will be skipped** when running as root — it must be installed separately as the target user.
- **Never run as root without `--user`**: All config files will go to `/root/` instead of the actual user's home, and Homebrew will fail.

To pass `--user` through the orchestrator:
```powershell
.\mac-my-wsl.ps1 -Distro Ubuntu -BootstrapArgs "--user,scott"
```

## Error recovery

| Problem | Solution |
|---------|----------|
| "sudo requires a password" error | Grant passwordless sudo: `echo "user ALL=(ALL) NOPASSWD:ALL" \| sudo tee /etc/sudoers.d/user`, or run as root with `--user`. |
| Homebrew install fails as root | Expected — run `wsl -d <Distro> -u <user> -- bash -c "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/brew.sh && NONINTERACTIVE=1 bash /tmp/brew.sh"` |
| Homebrew install hangs or quoting errors | Download the installer script first, then run it (see above). Do not use nested `bash -c "$(curl ...)"` through PowerShell→WSL. |
| `fzf` or other package "not available" during dry-run | Expected — `apt-get update` was also dry-run'd so the package cache is empty. The real run will work. |
| Starship or brew "not installed" in summary | If brew was skipped (root run), install it as the target user first, then `brew install starship`. |
| Font icons not rendering | Install JetBrainsMono Nerd Font and restart Windows Terminal. |

## Post-setup verification

After setup completes, verify key tools are working:
```bash
wsl -d <Distro> -u <user> -- zsh -lc 'which brew && brew --version | head -1 && which starship && starship --version | head -1 && which pbcopy && echo "✅ All tools working"'
```

If any tool is missing, check the bootstrap log file (path printed at the end of the run).

## Safety and expectations

- Validate distro exists with `wsl -l -q` before running.
- Prefer dry-run first unless the customer says to apply immediately.
- This setup is designed to be idempotent and safe to rerun.
- If bootstrap used `--dry-run`, Windows-side customization steps are intentionally skipped.
