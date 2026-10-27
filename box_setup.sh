#!/usr/bin/env bash
# Installs personal tools into $HOME so they survive Dev Container rebuilds
# (/home/ubuntu is a named volume; anything installed with apt is lost on rebuild).
# Safe to re-run: tools that are already installed are skipped. Set DEVTOOLS_UPDATE=1 to
# reinstall them at their latest release.
# Terminals start in zsh; set DEVTOOLS_NO_ZSH=1 to stay in bash.
#
#   curl -fsSL https://mneira10.github.io/box_setup.sh | bash
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
OPT_DIR="$HOME/.local/opt"
SHELL_RC="$HOME/.config/devtools.bash"
mkdir -p "$BIN_DIR" "$OPT_DIR" "$(dirname "$SHELL_RC")"
export PATH="$BIN_DIR:$PATH"

# Release assets don't agree on architecture names:
#   {arch}  x86_64 / aarch64   (Rust-style targets)
#   {goarch} amd64 / arm64     (Go-style)
#   {mixed} x86_64 / arm64     (Neovim, lazygit)
case "$(uname -m)" in
  x86_64 | amd64) ARCH=x86_64 GOARCH=amd64 MIXED_ARCH=x86_64 ;;
  aarch64 | arm64) ARCH=aarch64 GOARCH=arm64 MIXED_ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

log() { printf '\n==> %s\n' "$*"; }

# Succeeds if `name` should be installed: it isn't on PATH (or at `path`, if given), or
# DEVTOOLS_UPDATE is set.
needs_install() {
  local name="$1" path="${2:-}"
  if [ -n "${DEVTOOLS_UPDATE:-}" ]; then
    return 0
  elif [ -n "$path" ]; then
    [ -e "$path" ] || return 0
  else
    path="$(command -v "$name")" || return 0
  fi
  log "$name is already installed at $path, skipping"
  return 1
}

# Prints the latest release tag of a GitHub repo, e.g. `v10.5.0`. Follows the
# /releases/latest redirect instead of using the API, which is rate limited.
latest_tag() {
  local url
  url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")"
  echo "${url##*/}"
}

# Downloads the latest release tarball of a GitHub repo and copies the named binary
# from it into $BIN_DIR. `asset` may use {tag}, {version} (the tag without a leading
# `v`), {arch}, {goarch} and {mixed}.
install_github_binary() {
  local repo="$1" asset="$2" binary="$3" tag tmp
  needs_install "$binary" || return 0
  log "Installing $binary"
  tag="$(latest_tag "$repo")"
  asset="${asset//\{tag\}/$tag}"
  asset="${asset//\{version\}/${tag#v}}"
  asset="${asset//\{arch\}/$ARCH}"
  asset="${asset//\{goarch\}/$GOARCH}"
  asset="${asset//\{mixed\}/$MIXED_ARCH}"
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/$repo/releases/download/$tag/$asset" | tar -xz -C "$tmp"
  install -m 0755 "$(find "$tmp" -type f -name "$binary" | head -1)" "$BIN_DIR/$binary"
  rm -rf "$tmp"
}

if needs_install nvim; then
  log "Installing Neovim"
  rm -rf "$OPT_DIR/nvim"
  mkdir -p "$OPT_DIR/nvim"
  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${MIXED_ARCH}.tar.gz" \
    | tar -xz -C "$OPT_DIR/nvim" --strip-components=1
  ln -sf "$OPT_DIR/nvim/bin/nvim" "$BIN_DIR/nvim"
fi

install_github_binary aristocratos/btop "btop-{arch}-unknown-linux-musl.tar.gz" btop
install_github_binary BurntSushi/ripgrep "ripgrep-{version}-{arch}-unknown-linux-musl.tar.gz" rg
install_github_binary sharkdp/fd "fd-{tag}-{arch}-unknown-linux-musl.tar.gz" fd
install_github_binary sharkdp/bat "bat-{tag}-{arch}-unknown-linux-musl.tar.gz" bat
install_github_binary jesseduffield/lazygit "lazygit_{version}_linux_{mixed}.tar.gz" lazygit
install_github_binary junegunn/fzf "fzf-{version}-linux_{goarch}.tar.gz" fzf
install_github_binary ajeetdsouza/zoxide "zoxide-{version}-{arch}-unknown-linux-musl.tar.gz" zoxide
install_github_binary starship/starship "starship-{arch}-unknown-linux-musl.tar.gz" starship

if needs_install herdr; then
  log "Installing herdr"
  curl -fsSL https://herdr.dev/install.sh | HERDR_INSTALL_DIR="$BIN_DIR" sh
fi

# A static zsh build, since zsh from apt would be lost on every Dev Container rebuild. The
# shell config below runs ~/.local/bin/zsh, so a zsh elsewhere on PATH doesn't count.
if needs_install zsh "$BIN_DIR/zsh"; then
  log "Installing zsh"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)" \
    -- -q -d "$HOME/.local" -e no
fi

ANTIDOTE_DIR="$HOME/.local/share/antidote"
if [ -d "$ANTIDOTE_DIR/.git" ]; then
  if [ -n "${DEVTOOLS_UPDATE:-}" ]; then
    log "Updating antidote (zsh plugin manager)"
    git -C "$ANTIDOTE_DIR" pull --quiet --ff-only
  else
    log "antidote is already installed at $ANTIDOTE_DIR, skipping"
  fi
else
  log "Installing antidote (zsh plugin manager)"
  git clone --quiet --depth 1 https://github.com/mattmc3/antidote "$ANTIDOTE_DIR"
fi

log "Configuring bash and zsh"
# The files under ~/.config/devtools/ are rewritten on every run. Put your own additions
# in ~/.bashrc and ~/.zshrc instead.
mkdir -p "$HOME/.config/devtools"
rm -f "$HOME/.config/devtools.bash"  # Moved into ~/.config/devtools/.

cat >"$HOME/.config/devtools/bashrc" <<'RC'
export PATH="$HOME/.local/bin:$PATH"
# Terminals start bash, so hand interactive sessions over to zsh. Skip `bash -c`
# (editors and agents run commands that way) and set DEVTOOLS_NO_ZSH=1 to stay in bash.
if [[ $- == *i* && -z ${BASH_EXECUTION_STRING:-} && -t 0 && -z ${DEVTOOLS_NO_ZSH:-} \
      && -x $HOME/.local/bin/zsh ]]; then
  export SHELL="$HOME/.local/bin/zsh"
  exec "$SHELL" -l
fi
if [[ $- == *i* ]]; then
  eval "$(fzf --bash)"         # Ctrl-R history search, Ctrl-T file search, Alt-C cd
  eval "$(zoxide init bash)"   # `z <dir>` jumps to frequently used directories
fi
RC

cat >"$HOME/.config/devtools/zsh_plugins.txt" <<'PLUGINS'
# Defers compinit until all plugins have added their completions.
mattmc3/ez-compinit
zsh-users/zsh-completions kind:fpath path:src
# Git aliases like gst, gco, gcmsg, gp (see `alias | grep git`).
ohmyzsh/ohmyzsh path:lib/git.zsh
ohmyzsh/ohmyzsh path:plugins/git
zsh-users/zsh-autosuggestions
# Must be last so it can highlight what the other plugins define.
zsh-users/zsh-syntax-highlighting
PLUGINS

cat >"$HOME/.config/devtools/zshrc" <<'RC'
export PATH="$HOME/.local/bin:$PATH"
export SHELL="$HOME/.local/bin/zsh"

HISTFILE=~/.zsh_history
HISTSIZE=32768
SAVEHIST=32768
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE \
  HIST_REDUCE_BLANKS HIST_VERIFY
setopt COMPLETE_IN_WORD ALWAYS_TO_END AUTO_LIST AUTO_MENU
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

source "$HOME/.local/share/antidote/antidote.zsh"
antidote load "$HOME/.config/devtools/zsh_plugins.txt"

# The oh-my-zsh git plugin's `gl` is `git pull`; use a compact log graph instead.
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cd) %C(bold blue)<%an>%Creset' --date=short"

eval "$(fzf --zsh)"            # Ctrl-R history search, Ctrl-T file search, Alt-C cd
eval "$(zoxide init zsh)"      # `z <dir>` jumps to frequently used directories
eval "$(starship init zsh)"
RC

# Adds `line` to `file` unless something already matches `pattern`.
ensure_line() {
  local file="$1" pattern="$2" line="$3"
  touch "$file"
  grep -qsF "$pattern" "$file" || echo "$line" >>"$file"
}
# Earlier versions of this script sourced ~/.config/devtools.bash.
sed -i '/\.config\/devtools\.bash/d' "$HOME/.bashrc" 2>/dev/null || true
ensure_line "$HOME/.bashrc" '.config/devtools/bashrc' 'source "$HOME/.config/devtools/bashrc"'
ensure_line "$HOME/.zshrc" '.config/devtools/zshrc' 'source "$HOME/.config/devtools/zshrc"'

if [ ! -e "$HOME/.config/starship.toml" ]; then
  cat >"$HOME/.config/starship.toml" <<'TOML'
add_newline = true
command_timeout = 200
format = "[$directory$git_branch$git_status]($style)$character"

[character]
error_symbol = "[✗](bold cyan)"
success_symbol = "[❯](bold cyan)"

[directory]
truncation_length = 2
truncation_symbol = "…/"
repo_root_style = "bold cyan"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "

[git_branch]
format = "[$branch]($style) "
style = "italic cyan"

[git_status]
format     = '[$all_status]($style)'
style      = "cyan"
ahead      = "⇡${count} "
diverged   = "⇕⇡${ahead_count}⇣${behind_count} "
behind     = "⇣${count} "
conflicted = " "
up_to_date = " "
untracked  = "? "
modified   = " "
stashed    = ""
staged     = ""
renamed    = ""
deleted    = ""
TOML
fi

# Download the zsh plugins now so the first terminal doesn't have to.
"$BIN_DIR/zsh" -c "source '$ANTIDOTE_DIR/antidote.zsh' && antidote load '$HOME/.config/devtools/zsh_plugins.txt'"

log "Installing LazyVim"
if [ -e "$HOME/.config/nvim" ]; then
  echo "~/.config/nvim already exists, leaving it alone."
else
  git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
fi
# This file is rewritten on every run; put your own plugin config in other files.
mkdir -p "$HOME/.config/nvim/lua/plugins"
cat >"$HOME/.config/nvim/lua/plugins/devtools.lua" <<'LUA'
-- Show dotfiles like .github in the explorer and pickers. Gitignored files like .venv
-- stay hidden; toggle them with `I` in the explorer or Alt-i in pickers.
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = { hidden = true },
        files = { hidden = true },
        grep = { hidden = true },
      },
    },
  },
}
LUA
# Download plugins now so the first `nvim` doesn't have to.
nvim --headless "+Lazy! sync" +qa

log "Installed"
for tool in zsh starship nvim btop rg fd bat lazygit fzf zoxide herdr; do
  printf '%-8s %s\n' "$tool" "$("$tool" --version 2>&1 | head -1)"
done

# This script runs in its own process, so it can't change the shell that launched it.
log "Done. To switch this shell to zsh with the new tools, run:"
echo
echo "    source ~/.bashrc"
echo
echo "New terminals start in zsh automatically."
