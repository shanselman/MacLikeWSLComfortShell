#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
NO_BREW=0
MINIMAL=0
FORCE=0
IS_ROOT=0
TARGET_USER=""
LOG_FILE=""
APT_UPDATED=0

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--user <name>] [--minimal] [--no-brew] [--force] [--dry-run] [--help]

Options:
  --user <name>  Configure this user's environment (requires root).
                 Defaults to the current user.
  --minimal      Skip optional extras (brew formulae and zsh plugins).
  --no-brew      Do not install or configure Homebrew packages.
  --force        Overwrite managed files and existing managed-compatible shims.
  --dry-run      Print planned actions without applying changes.
  --help         Show this help message.
EOF
}

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run]'
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    return 0
  fi
  "$@"
}

# Run a command that normally needs sudo; skip sudo when already root.
run_privileged() {
  if [ "$IS_ROOT" -eq 1 ]; then
    run "$@"
  else
    run sudo "$@"
  fi
}

# Run a command as the target user (for git config, chsh, etc.).
run_as_target() {
  if [ "$IS_ROOT" -eq 1 ] && [ "$TARGET_USER" != "root" ] && [ "$TARGET_USER" != "$USER" ]; then
    run sudo -H -u "$TARGET_USER" -- "$@"
  else
    run "$@"
  fi
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null || [ -d /run/WSL ] || [ -n "${WSL_DISTRO_NAME:-}" ]
}

setup_logging() {
  local log_dir
  log_dir="$HOME/wsl-mac-setup/logs"
  mkdir -p "$log_dir"
  LOG_FILE="$log_dir/$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  info "Logging to $LOG_FILE"
}

apt_update_once() {
  if [ "$APT_UPDATED" -eq 1 ]; then
    return 0
  fi
  info "Running apt-get update"
  run_privileged apt-get update
  APT_UPDATED=1
}

ensure_apt_package() {
  local pkg="$1"
  local optional="${2:-0}"

  if dpkg -s "$pkg" >/dev/null 2>&1; then
    info "apt package present: $pkg"
    return 0
  fi

  # In dry-run mode, apt-cache may be empty (apt update was also dry-run),
  # so skip the availability check and just report what would happen.
  if [ "$DRY_RUN" -eq 1 ]; then
    info "Would install apt package: $pkg"
    return 0
  fi

  if ! apt-cache show "$pkg" >/dev/null 2>&1; then
    if [ "$optional" -eq 1 ]; then
      warn "Optional apt package not available: $pkg"
      return 0
    fi
    die "Required apt package not available: $pkg"
  fi

  info "Installing apt package: $pkg"
  if ! run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
    if [ "$optional" -eq 1 ]; then
      warn "Optional apt package failed to install: $pkg"
      return 0
    fi
    die "Failed to install required apt package: $pkg"
  fi
}

append_managed_block() {
  local file="$1"
  local marker="$2"
  local content="$3"
  local start end tmp
  local start_count end_count start_line end_line
  start="# >>> ${marker} >>>"
  end="# <<< ${marker} <<<"

  if [ "$DRY_RUN" -eq 1 ]; then
    info "Would update managed block in $file"
    return 0
  fi

  mkdir -p "$(dirname "$file")"
  touch "$file"
  start_count="$(grep -Fxc "$start" "$file" || true)"
  end_count="$(grep -Fxc "$end" "$file" || true)"
  if [ "$start_count" -ne "$end_count" ]; then
    die "Managed block markers are unbalanced in $file for marker '$marker'"
  fi
  if [ "$start_count" -gt 1 ]; then
    die "Managed block marker appears multiple times in $file for marker '$marker'"
  fi
  if [ "$start_count" -eq 1 ]; then
    start_line="$(grep -Fnx "$start" "$file" | cut -d: -f1 || true)"
    end_line="$(grep -Fnx "$end" "$file" | cut -d: -f1 || true)"
    if [ -z "$start_line" ] || [ -z "$end_line" ] || [ "$start_line" -ge "$end_line" ]; then
      die "Managed block markers are out of order in $file for marker '$marker'"
    fi
  fi
  tmp="$(mktemp)"

  awk -v start="$start" -v end="$end" '
    $0 == start { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$file" >"$tmp"
  awk '
    { lines[NR]=$0 }
    NF { last_nonempty=NR }
    END {
      if (last_nonempty > 0) {
        for (i=1; i<=last_nonempty; i++) {
          print lines[i]
        }
      }
    }
  ' "$tmp" >"${tmp}.trim"
  mv "${tmp}.trim" "$tmp"

  {
    cat "$tmp"
    if [ -s "$tmp" ]; then
      printf '\n'
    fi
    printf '%s\n' "$start"
    printf '%s\n' "$content"
    printf '%s\n' "$end"
  } >"${tmp}.new"

  mv "${tmp}.new" "$file"
  rm -f "$tmp"
  info "Updated managed block in $file"
}

write_text_file() {
  local path="$1"
  local mode="$2"
  local content="$3"

  if [ "$DRY_RUN" -eq 1 ]; then
    info "Would write $path"
    return 0
  fi

  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" >"$path"
  chmod "$mode" "$path"
  info "Wrote $path"
}

install_shim() {
  local path="$1"
  local content="$2"

  if [ -f "$path" ] && [ "$FORCE" -eq 0 ] && ! grep -q "wsl-mac-comfort shim" "$path"; then
    warn "Skipping existing non-managed shim: $path (use --force to overwrite)"
    return 0
  fi
  write_text_file "$path" 755 "$content"
}

load_brew_shellenv() {
  if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    # shellcheck disable=SC1091
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [ -x "${TARGET_HOME:-$HOME}/.linuxbrew/bin/brew" ]; then
    # shellcheck disable=SC1091
    eval "$("${TARGET_HOME:-$HOME}/.linuxbrew/bin/brew" shellenv)"
  fi
}

ensure_brew_formula() {
  local formula="$1"
  if ! has_cmd brew; then
    return 0
  fi
  if brew list --formula "$formula" >/dev/null 2>&1; then
    info "brew formula present: $formula"
    return 0
  fi

  info "Installing brew formula: $formula"
  if ! run brew install "$formula"; then
    warn "brew install failed for $formula"
  fi
}

ensure_git_clone() {
  local repo="$1"
  local dest="$2"

  if [ -d "$dest/.git" ]; then
    info "git repo present: $dest"
    return 0
  fi

  if [ -e "$dest" ]; then
    warn "Path exists and is not a git checkout, skipping: $dest"
    return 0
  fi

  info "Cloning $repo into $dest"
  if ! run_as_target git clone --depth 1 "$repo" "$dest"; then
    warn "Failed to clone $repo"
  fi
}

ensure_git_config() {
  local key="$1"
  local value="$2"
  local current

  # Read check: run directly (not through dry-run wrapper).
  if [ "$IS_ROOT" -eq 1 ] && [ "$TARGET_USER" != "root" ] && [ "$TARGET_USER" != "$USER" ]; then
    current="$(sudo -H -u "$TARGET_USER" -- git config --global --get "$key" 2>/dev/null || true)"
  else
    current="$(git config --global --get "$key" 2>/dev/null || true)"
  fi
  if [ -n "$current" ] && [ "$FORCE" -eq 0 ]; then
    info "git config already set: $key=$current"
    return 0
  fi

  info "Setting git config: $key=$value"
  run_as_target git config --global "$key" "$value"
}

print_version_line() {
  local tool="$1"
  local cmd="$2"
  if has_cmd "$tool"; then
    # shellcheck disable=SC2086
    local line
    line="$(eval "$cmd" 2>/dev/null | head -n 1 || true)"
    printf '  - %-10s %s\n' "$tool" "${line:-installed}"
  else
    printf '  - %-10s %s\n' "$tool" "not installed"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --minimal) MINIMAL=1 ;;
    --no-brew) NO_BREW=1 ;;
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --user)
      shift
      [ $# -gt 0 ] || die "--user requires a username argument."
      TARGET_USER="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1 (use --help)"
      ;;
  esac
  shift
done

setup_logging
info "Starting WSL Mac Comfort bootstrap"

if ! is_wsl; then
  die "This script is intended for WSL."
fi

if [ ! -f /etc/os-release ]; then
  die "Cannot detect Linux distribution (missing /etc/os-release)."
fi

# shellcheck disable=SC1091
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ] && [ "${ID:-}" != "debian" ]; then
  die "Unsupported distro: ${ID:-unknown}. Supported: ubuntu, debian."
fi

if [[ "$PWD" == /mnt/[a-zA-Z]/* ]]; then
  warn "Current directory is under /mnt/... . Builds and file-heavy tasks may be slower there."
fi

IS_ROOT=0
if [ "$EUID" -eq 0 ]; then
  IS_ROOT=1
elif ! sudo -n true 2>/dev/null; then
  die "sudo requires a password. Either run as root, grant passwordless sudo (e.g. 'echo \"$USER ALL=(ALL) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/$USER'), or use --dry-run to preview."
fi

# Resolve target user for dotfiles/shims/configs.
if [ -z "$TARGET_USER" ]; then
  TARGET_USER="$USER"
fi
if [ "$TARGET_USER" = "$USER" ]; then
  TARGET_HOME="$HOME"
else
  if [ "$IS_ROOT" -eq 0 ]; then
    die "Cannot configure another user without root. Run as root with --user $TARGET_USER."
  fi
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  if [ -z "$TARGET_HOME" ]; then
    die "User '$TARGET_USER' not found in passwd database."
  fi
  info "Configuring environment for user '$TARGET_USER' (home: $TARGET_HOME)"
fi

# Create target user directories with correct ownership.
if [ "$IS_ROOT" -eq 1 ] && [ "$TARGET_USER" != "root" ]; then
  install -d -o "$TARGET_USER" "$TARGET_HOME/bin" "$TARGET_HOME/src" "$TARGET_HOME/.config/wsl-mac"
else
  mkdir -p "$TARGET_HOME/bin" "$TARGET_HOME/src" "$TARGET_HOME/.config/wsl-mac"
fi
export PATH="$TARGET_HOME/bin:$PATH"

apt_update_once
required_apt=(
  build-essential curl wget git ca-certificates gnupg lsb-release unzip zip jq
  pkg-config python3 python3-venv zsh fzf ripgrep fd-find bat man-db
)
optional_apt=(pipx eza btop htop tmux tldr socat xclip xdg-utils wslu)

for pkg in "${required_apt[@]}"; do
  ensure_apt_package "$pkg" 0
done
for pkg in "${optional_apt[@]}"; do
  ensure_apt_package "$pkg" 1
done

if [ "$MINIMAL" -eq 0 ]; then
  ensure_apt_package zsh-autosuggestions 1
  ensure_apt_package zsh-syntax-highlighting 1
else
  info "Skipping zsh plugins because --minimal was provided"
fi

if ! has_cmd fd && has_cmd fdfind; then
  install_shim "$TARGET_HOME/bin/fd" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
exec fdfind "$@"
EOF
)"
fi

if ! has_cmd bat && has_cmd batcat; then
  install_shim "$TARGET_HOME/bin/bat" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
exec batcat "$@"
EOF
)"
fi

install_shim "$TARGET_HOME/bin/pbcopy" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
clip.exe
EOF
)"

install_shim "$TARGET_HOME/bin/pbpaste" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\r'
EOF
)"

install_shim "$TARGET_HOME/bin/open" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
if [ "$#" -lt 1 ]; then
  echo "Usage: open <url-or-path>" >&2
  exit 1
fi
target="$*"
if [ -e "$1" ]; then
  target="$(wslpath -w "$1")"
fi
cmd.exe /c start "" "$target" >/dev/null 2>&1
EOF
)"

if ! has_cmd xdg-open; then
  install_shim "$TARGET_HOME/bin/xdg-open" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
exec open "$@"
EOF
)"
fi

if ! has_cmd x-www-browser; then
  install_shim "$TARGET_HOME/bin/x-www-browser" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
exec open "$@"
EOF
)"
fi

if ! has_cmd www-browser; then
  install_shim "$TARGET_HOME/bin/www-browser" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
exec open "$@"
EOF
)"
fi

if ! has_cmd wslview; then
  install_shim "$TARGET_HOME/bin/wslview" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# wsl-mac-comfort shim
exec open "$@"
EOF
)"
fi

if [ "$NO_BREW" -eq 0 ]; then
  if [ "$IS_ROOT" -eq 1 ]; then
    warn "Homebrew cannot run as root. Skipping brew install and formulae."
    warn "To install brew, re-run as the target user or run: sudo -u $TARGET_USER bash $0 --user $TARGET_USER"
  else
    if ! has_cmd brew; then
      info "Installing Homebrew"
      brew_tmp="$(mktemp)"
      if curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$brew_tmp"; then
        if ! run env NONINTERACTIVE=1 bash "$brew_tmp"; then
          warn "Homebrew install failed; continuing."
        fi
      else
        warn "Failed to download Homebrew installer; continuing."
      fi
      rm -f "$brew_tmp"
    else
      info "Homebrew already installed"
    fi

    if [ "$DRY_RUN" -eq 0 ]; then
      load_brew_shellenv
    fi

    if has_cmd brew; then
      if [ "$MINIMAL" -eq 0 ]; then
        for formula in starship gh direnv zoxide yq btop fnm; do
          ensure_brew_formula "$formula"
        done
      else
        info "Skipping brew formula installs because --minimal was provided"
      fi

      if ! run brew doctor; then
        warn "brew doctor reported warnings."
      fi
    else
      warn "brew is not available after install attempt."
    fi
  fi
else
  info "Skipping Homebrew because --no-brew was provided"
fi

zprofile_block="$(cat <<'EOF'
export PATH="$HOME/bin:$PATH"
if [ -d /home/linuxbrew/.linuxbrew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d "$HOME/.linuxbrew" ]; then
  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi
if [ -z "${BROWSER:-}" ]; then
  if command -v xdg-open >/dev/null 2>&1; then
    export BROWSER=xdg-open
  elif command -v wslview >/dev/null 2>&1; then
    export BROWSER=wslview
  elif command -v open >/dev/null 2>&1; then
    export BROWSER=open
  fi
fi
EOF
)"
append_managed_block "$TARGET_HOME/.zprofile" "wsl-mac-comfort" "$zprofile_block"

zshrc_block="$(cat <<'EOF'
export PATH="$HOME/bin:$PATH"
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons'
  alias ll='eza -la --icons --git'
  alias lt='eza --tree'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat'
command -v rg >/dev/null 2>&1 && alias grep='rg'
command -v fd >/dev/null 2>&1 && alias find='fd'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
EOF
)"
append_managed_block "$TARGET_HOME/.zshrc" "wsl-mac-comfort" "$zshrc_block"

starship_cfg="$TARGET_HOME/.config/starship.toml"
if [ ! -f "$starship_cfg" ] || [ "$FORCE" -eq 1 ]; then
  write_text_file "$starship_cfg" 644 "$(cat <<'EOF'
add_newline = false

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"

[directory]
truncation_length = 4
truncate_to_repo = false
EOF
)"
else
  info "Keeping existing $starship_cfg (use --force to overwrite)"
fi

if [ "$MINIMAL" -eq 0 ] && has_cmd tmux; then
  ensure_git_clone "https://github.com/tmux-plugins/tpm" "$TARGET_HOME/.tmux/plugins/tpm"
  tmux_cfg="$TARGET_HOME/.tmux.conf"
  if [ ! -f "$tmux_cfg" ] || [ "$FORCE" -eq 1 ]; then
    write_text_file "$tmux_cfg" 644 "$(cat <<'EOF'
set -g mouse on
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix
bind | split-window -h
bind - split-window -v
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
run '~/.tmux/plugins/tpm/tpm'
EOF
)"
  else
    info "Keeping existing $tmux_cfg (use --force to overwrite)"
  fi
fi

ensure_git_config init.defaultBranch main
ensure_git_config pull.rebase false
ensure_git_config core.autocrlf input

if has_cmd zsh; then
  zsh_path="$(command -v zsh)"
  current_shell="$(getent passwd "$TARGET_USER" | awk -F: '{print $7}')"
  if [ "$current_shell" != "$zsh_path" ]; then
    warn "Default shell for $TARGET_USER is $current_shell. Attempting to switch to $zsh_path."
    if [ "$DRY_RUN" -eq 1 ]; then
      info "Would run: chsh -s \"$zsh_path\" \"$TARGET_USER\""
    else
      if run_privileged chsh -s "$zsh_path" "$TARGET_USER"; then
        info "Default shell changed to zsh for $TARGET_USER"
      else
        warn "Could not change default shell automatically."
      fi
    fi
  fi
fi

# Fix ownership of all written files when running as root for another user.
if [ "$IS_ROOT" -eq 1 ] && [ "$TARGET_USER" != "root" ] && [ "$DRY_RUN" -eq 0 ]; then
  info "Fixing ownership of $TARGET_HOME files for $TARGET_USER"
  chown -R "$TARGET_USER" \
    "$TARGET_HOME/bin" \
    "$TARGET_HOME/src" \
    "$TARGET_HOME/.config" \
    "$TARGET_HOME/.zprofile" \
    "$TARGET_HOME/.zshrc" \
    2>/dev/null || true
  # Also fix tmux and git dirs if they exist
  for p in "$TARGET_HOME/.tmux" "$TARGET_HOME/.tmux.conf" "$TARGET_HOME/.gitconfig"; do
    [ -e "$p" ] && chown -R "$TARGET_USER" "$p" 2>/dev/null || true
  done
fi

printf '\nSummary checks:\n'
print_version_line zsh "zsh --version"
print_version_line brew "brew --version"
print_version_line make "make --version"
print_version_line gcc "gcc --version"
print_version_line rg "rg --version"
print_version_line starship "starship --version"

cat <<EOF

Next steps:
  1) Restart your terminal (or run: exec zsh -l)
  2) Keep repos in ~/src for best performance
  3) Use 'code .' from inside WSL for VS Code Remote WSL
  4) Install tools with brew install <package>

Log file:
  $LOG_FILE
EOF
