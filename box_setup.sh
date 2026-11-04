#!/usr/bin/env bash
# Installs personal tools into $HOME so they survive Dev Container rebuilds
# (/home/ubuntu is a named volume; anything installed with apt is lost on rebuild).
# Safe to re-run: each run updates every tool to its latest release, skipping downloads
# for tools that are already current.
# Points Claude Code and Codex at the CLIProxyAPI proxy; the script asks for the key, or
# reads it from $CLIPROXY_API_KEY when there's no terminal.
# Terminals start in zsh; set DEVTOOLS_NO_ZSH=1 to stay in bash.
#
#   curl -fsSL https://mneira10.github.io/box_setup.sh | bash
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
OPT_DIR="$HOME/.local/opt"
VERSIONS_DIR="$HOME/.local/share/devtools/versions"
mkdir -p "$BIN_DIR" "$OPT_DIR" "$VERSIONS_DIR" "$HOME/.config"
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

# Succeeds if `name` should be (re)installed: `path` is missing, or it was installed from
# a release other than `version`. Call mark_installed after installing it.
needs_update() {
  local name="$1" version="$2" path="$3"
  if [ -e "$path" ] && [ "$(cat "$VERSIONS_DIR/$name" 2>/dev/null)" = "$version" ]; then
    log "$name is up to date ($version)"
    return 1
  fi
}

mark_installed() {
  echo "$2" >"$VERSIONS_DIR/$1"
}

# Prints the latest release tag of a GitHub repo, e.g. `v10.5.0`. Follows the
# /releases/latest redirect instead of using the API, which is rate limited.
latest_tag() {
  local url
  url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")"
  echo "${url##*/}"
}

# Downloads the latest release of a GitHub repo and copies the named binary into
# $BIN_DIR. `asset` is either a tarball containing the binary or the binary itself, and
# may use {tag}, {version} (the tag without a leading `v`), {arch}, {goarch} and {mixed}.
install_github_binary() {
  local repo="$1" asset="$2" binary="$3" tag tmp
  tag="$(latest_tag "$repo")"
  needs_update "$binary" "$tag" "$BIN_DIR/$binary" || return 0
  log "Installing $binary $tag"
  asset="${asset//\{tag\}/$tag}"
  asset="${asset//\{version\}/${tag#v}}"
  asset="${asset//\{arch\}/$ARCH}"
  asset="${asset//\{goarch\}/$GOARCH}"
  asset="${asset//\{mixed\}/$MIXED_ARCH}"
  tmp="$(mktemp -d)"
  if [[ $asset == *.tar.gz ]]; then
    curl -fsSL "https://github.com/$repo/releases/download/$tag/$asset" | tar -xz -C "$tmp"
  else
    curl -fsSL -o "$tmp/$binary" "https://github.com/$repo/releases/download/$tag/$asset"
  fi
  install -m 0755 "$(find "$tmp" -type f -name "$binary" | head -1)" "$BIN_DIR/$binary"
  rm -rf "$tmp"
  mark_installed "$binary" "$tag"
}

# Keep one installed copy, shared by Codex and Claude. A local checkout supplies the
# files directly; curl | bash downloads them from this repo, like the tools above.
install_agent_skills() (
  local setup_script="${1:-}" source_dir="" tmp="" skill agent target link backup
  local skills_dir="$HOME/.local/share/devtools/skills"
  local backups_dir="$HOME/.local/share/devtools/skill-backups"
  local skills=(upcodes-pr-review grill-me)
  trap '[ -z "$tmp" ] || rm -rf "$tmp"' EXIT

  if [ -n "$setup_script" ] && [ -d "$(dirname "$setup_script")/skills" ]; then
    source_dir="$(cd "$(dirname "$setup_script")/skills" && pwd)"
  fi

  if [ -z "$source_dir" ]; then
    log "Downloading agent skills"
    tmp="$(mktemp -d)"
    curl -fsSL https://github.com/mneira10/mneira10.github.io/archive/refs/heads/master.tar.gz \
      | tar -xz -C "$tmp" --strip-components=1
    source_dir="$tmp/skills"
  fi
  # Check the bundle before replacing any installed skills.
  for skill in "${skills[@]}"; do
    if [ ! -f "$source_dir/$skill/SKILL.md" ]; then
      echo "Missing skill: $source_dir/$skill/SKILL.md" >&2
      exit 1
    fi
  done

  mkdir -p "$skills_dir" "$HOME/.codex/skills" "$HOME/.claude/skills"
  for skill in "${skills[@]}"; do
    target="$skills_dir/$skill"
    log "Installing $skill skill"
    rm -rf "$target"
    cp -R "$source_dir/$skill" "$target"

    for agent in codex claude; do
      link="$HOME/.$agent/skills/$skill"
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        continue
      fi
      # Keep pre-existing copies outside the discovery directories, so they don't
      # appear as duplicate skills. Unrelated skills are never touched.
      if [ -e "$link" ] && [ ! -L "$link" ]; then
        mkdir -p "$backups_dir"
        backup="$(mktemp -d "$backups_dir/$agent-$skill.XXXXXX")"
        mv "$link" "$backup/$skill"
        log "Backed up $link to $backup/$skill"
      fi
      ln -sfnT "$target" "$link"
    done
  done
)

install_agent_skills "${BASH_SOURCE[0]:-}"

NVIM_TAG="$(latest_tag neovim/neovim)"
if needs_update nvim "$NVIM_TAG" "$BIN_DIR/nvim"; then
  log "Installing Neovim $NVIM_TAG"
  rm -rf "$OPT_DIR/nvim"
  mkdir -p "$OPT_DIR/nvim"
  curl -fsSL "https://github.com/neovim/neovim/releases/download/$NVIM_TAG/nvim-linux-${MIXED_ARCH}.tar.gz" \
    | tar -xz -C "$OPT_DIR/nvim" --strip-components=1
  ln -sf "$OPT_DIR/nvim/bin/nvim" "$BIN_DIR/nvim"
  mark_installed nvim "$NVIM_TAG"
fi

install_github_binary aristocratos/btop "btop-{arch}-unknown-linux-musl.tar.gz" btop
install_github_binary BurntSushi/ripgrep "ripgrep-{version}-{arch}-unknown-linux-musl.tar.gz" rg
install_github_binary sharkdp/fd "fd-{tag}-{arch}-unknown-linux-musl.tar.gz" fd
install_github_binary sharkdp/bat "bat-{tag}-{arch}-unknown-linux-musl.tar.gz" bat
install_github_binary jesseduffield/lazygit "lazygit_{version}_linux_{mixed}.tar.gz" lazygit
install_github_binary junegunn/fzf "fzf-{version}-linux_{goarch}.tar.gz" fzf
install_github_binary ajeetdsouza/zoxide "zoxide-{version}-{arch}-unknown-linux-musl.tar.gz" zoxide
install_github_binary starship/starship "starship-{arch}-unknown-linux-musl.tar.gz" starship
install_github_binary jqlang/jq "jq-linux-{goarch}" jq

# The installer downloads whatever release this manifest names.
HERDR_VERSION="$(curl -fsSL https://herdr.dev/latest.json | jq -r .version)"
if needs_update herdr "$HERDR_VERSION" "$BIN_DIR/herdr"; then
  log "Installing herdr $HERDR_VERSION"
  curl -fsSL https://herdr.dev/install.sh | HERDR_INSTALL_DIR="$BIN_DIR" sh
  mark_installed herdr "$HERDR_VERSION"
fi

# A static zsh build, since zsh from apt would be lost on every Dev Container rebuild. The
# shell config below runs ~/.local/bin/zsh, so a zsh elsewhere on PATH doesn't count.
ZSH_BIN_TAG="$(latest_tag romkatv/zsh-bin)"
if needs_update zsh "$ZSH_BIN_TAG" "$BIN_DIR/zsh"; then
  log "Installing zsh $ZSH_BIN_TAG"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)" \
    -- -q -d "$HOME/.local" -e no
  mark_installed zsh "$ZSH_BIN_TAG"
fi

ANTIDOTE_DIR="$HOME/.local/share/antidote"
if [ -d "$ANTIDOTE_DIR/.git" ]; then
  log "Updating antidote (zsh plugin manager)"
  git -C "$ANTIDOTE_DIR" pull --quiet --ff-only
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
[ -f "$HOME/.config/devtools/secrets" ] && source "$HOME/.config/devtools/secrets"
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
# ~/.zshenv is read by every zsh, including non-interactive ones that agents start.
ensure_line "$HOME/.zshenv" '.config/devtools/secrets' \
  '[ -f "$HOME/.config/devtools/secrets" ] && source "$HOME/.config/devtools/secrets"'

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

# Download and update the zsh plugins now so the first terminal doesn't have to.
"$BIN_DIR/zsh" -c "source '$ANTIDOTE_DIR/antidote.zsh' \
  && antidote load '$HOME/.config/devtools/zsh_plugins.txt' && antidote update --bundles"

PROXY_URL="https://sweep-jawed-captivate.ngrok-free.dev"
SECRETS_FILE="$HOME/.config/devtools/secrets"

# Points Claude Code and Codex at the CLIProxyAPI proxy. The key is saved in
# $SECRETS_FILE, which bash and zsh source, and in Claude Code's settings. Asks for the
# key when there's a terminal (Enter keeps the current one); otherwise uses
# $CLIPROXY_API_KEY or the saved key.
configure_agent_proxy() {
  local key="${CLIPROXY_API_KEY:-}" input settings config tmp
  if [ -z "$key" ] && [ -f "$SECRETS_FILE" ]; then
    key="$(source "$SECRETS_FILE" && printf '%s' "${CLIPROXY_API_KEY:-}")"
  fi
  # curl | bash uses stdin for the script, so read the key from the terminal.
  if { : </dev/tty; } 2>/dev/null; then
    if [ -n "$key" ]; then
      printf 'CLIProxyAPI key (Enter keeps the current one): ' >/dev/tty
    else
      printf 'CLIProxyAPI key (Enter skips the proxy setup): ' >/dev/tty
    fi
    IFS= read -rs input </dev/tty || true
    printf '\n' >/dev/tty
    [ -z "$input" ] || key="$input"
  fi
  if [ -z "$key" ]; then
    log "No CLIProxyAPI key, skipping the Claude Code and Codex proxy setup"
    return 0
  fi

  log "Pointing Claude Code and Codex at $PROXY_URL"
  (umask 077 && printf 'export CLIPROXY_API_KEY=%q\n' "$key" >"$SECRETS_FILE")
  chmod 600 "$SECRETS_FILE"

  # Only the two env entries change; other settings are kept.
  settings="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  [ -s "$settings" ] || echo '{}' >"$settings"
  tmp="$(mktemp)"
  jq --arg url "$PROXY_URL" --arg key "$key" \
    '.env.ANTHROPIC_BASE_URL = $url | .env.ANTHROPIC_AUTH_TOKEN = $key' "$settings" >"$tmp"
  cat "$tmp" >"$settings"
  rm "$tmp"
  chmod 600 "$settings"

  # Rewrite the managed blocks between the markers. The top-level keys must come before
  # any table, and settings they replace are dropped so TOML doesn't see duplicate keys.
  config="$HOME/.codex/config.toml"
  mkdir -p "$HOME/.codex"
  touch "$config"
  tmp="$(mktemp)"
  {
    cat <<'TOML'
# >>> devtools cliproxy >>>
model_provider = "cliproxy"
model = "gpt-6.1-sol"
# <<< devtools cliproxy <<<

TOML
    awk '
      /^# >>> devtools cliproxy >>>/ { managed = 1; next }
      managed { if (/^# <<< devtools cliproxy <<</) managed = 0; next }
      /^[[:space:]]*\[/ { table = 1; cliproxy = /^[[:space:]]*\[model_providers\.cliproxy\]/ }
      cliproxy { next }
      !table && /^[[:space:]]*(model|model_provider)[[:space:]]*=/ { next }
      # Drop leading and trailing blank lines, so reruns do not add more.
      /^[[:space:]]*$/ { blanks = blanks "\n"; next }
      { if (printed) printf "%s", blanks; blanks = ""; printed = 1; print }
      END { if (printed) print "" }
    ' "$config"
    cat <<TOML
# >>> devtools cliproxy >>>
[model_providers.cliproxy]
name = "CLIProxyAPI"
base_url = "$PROXY_URL/v1"
wire_api = "responses"
env_key = "CLIPROXY_API_KEY"
# <<< devtools cliproxy <<<
TOML
  } >"$tmp"
  cat "$tmp" >"$config"
  rm "$tmp"
}

configure_agent_proxy

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
for tool in zsh starship nvim btop rg fd bat lazygit fzf zoxide jq herdr; do
  printf '%-8s %s\n' "$tool" "$("$tool" --version 2>&1 | head -1)"
done

# This script runs in its own process, so it can't change the shell that launched it.
log "Done. To switch this shell to zsh with the new tools, run:"
echo
echo "    source ~/.bashrc"
echo
echo "New terminals start in zsh automatically."
