# Give this to your agent

You are setting up a Windows + WSL machine so it feels like macOS for development.

Use this repository as an execution tool, not as a checklist:
- `mac-my-wsl.ps1` orchestrates setup and optional customizations.
- `wsl-mac-comfort-bootstrap.sh` configures the Linux side.
- `install-terminal-fragment.ps1` configures Windows Terminal profile defaults.

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

## Safety and expectations

- Validate distro exists with `wsl -l -q` before running.
- Prefer dry-run first unless the customer says to apply immediately.
- This setup is designed to be idempotent and safe to rerun.
- If bootstrap used `--dry-run`, Windows-side customization steps are intentionally skipped.
