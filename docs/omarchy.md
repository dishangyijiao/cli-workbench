# Omarchy (Arch Linux) migration

CLI Workbench can run on Omarchy, and Arch is now included in the automated container test matrix. Treat this as an incremental migration, not a one-click installation.

## Principles

- Keep Omarchy responsible for Hyprland, display, networking, themes and OS updates.
- Keep CLI Workbench responsible for tmux sessions, project switching, agent instructions and portable shell/editor settings.
- Do not edit `/usr/share/omarchy` or replace Omarchy's managed system files.
- Do not apply all chezmoi targets before reviewing the diff and confirming the pre-apply backup hook is installed.

## Prerequisites

On an Omarchy installation with pacman:

```sh
sudo pacman -S --needed git chezmoi zsh tmux fzf ripgrep jq neovim zoxide starship zsh-syntax-highlighting ghostty xdg-utils wl-clipboard diffutils fontconfig
```

Omarchy ships a Nerd Font and its own Ghostty configuration, and this repository leaves both alone on Linux. Install Coding Agents and their credentials separately; this repository deliberately does not manage secrets.

`diffutils` provides `diff` and `cmp`, both used by the regression suite and configuration comparison. Omitting it from a minimal Arch image produces misleading failures in otherwise unrelated tests.

## Safe first run

```sh
git clone https://github.com/dishangyijiao/cli-workbench.git ~/dev/cli-workbench
cd ~/dev/cli-workbench
bash tests/run.sh
chezmoi init --source "$PWD"
chezmoi doctor
chezmoi diff
chezmoi apply --dry-run
```

Review the output before applying individual targets. `chezmoi init` is important because this repository installs a backup-before-apply hook. Confirm its configuration before relying on the backups.

```sh
chezmoi apply ~/.tmux ~/.tmux.conf
# Test in an isolated tmux server, leaving existing sessions alone:
tmux -L workbench-test -f ~/.tmux.conf new-session
```

Deploy the remaining targets only after reviewing each diff. **Apply `~/.zshrc` last**: it replaces the existing file. Omarchy shell functions may depend on Bash; initially keep the system login shell unchanged and launch zsh explicitly from your preferred terminal.

## Known platform differences

- tmux loads `~/.tmux.conf` first and then `~/.config/tmux/tmux.conf`: both files, and on a conflict the later one wins (checked on tmux 3.8, the version Omarchy ships). Omarchy's file is the later one, so on an Omarchy host its prefix (`Ctrl+Space`, with `Ctrl+b` as the second prefix) and its `prefix` `v` split binding override this repository's `Ctrl+A` and `prefix` `v` copy-mode. See the effective prefix with `tmux -L probe new-session -d \; show -gv prefix \; kill-server`. To keep this repository's keys, change Omarchy's file yourself; this repository never edits it.
- Omarchy ships LazyVim in `~/.config/nvim`, and this repository also deploys `~/.config/nvim` (`init.lua`, `lua/`). Applying that target replaces Omarchy's `init.lua` and mixes the two plugin sets, so review `chezmoi diff` for it before applying.
- Omarchy owns the Ghostty theme and font, so `home/.chezmoiignore` deploys this repository's Ghostty config on macOS only. `scripts/accept-omarchy` checks that nothing is deployed on Linux and, with `--desktop`, that the installed Ghostty accepts the rendered template.
- tmux-fzf-url selects `xdg-open` when available, otherwise `open`. Check the effective `@fzf-url-open` option.
- Ctrl+backslash Neovim-aware pane navigation uses the existing tmux version helper; `bc` is not required.
- The Homebrew Brewfile is not an Arch package manifest.
- Validate SSH/Tailscale, clipboard and Wayland integration on the actual host. The Arch CI container validates scripts and chezmoi deployment, but cannot validate a Hyprland desktop session or Ghostty rendering.

## Reproducible host acceptance (before applying dotfiles)

Run these commands from the PR branch under a **local Ghostty window on the Omarchy host**, before changing the existing workstation config:

```sh
bash scripts/accept-omarchy --desktop
```

The check renders the full chezmoi source into a disposable HOME, starts a separate tmux server on a private socket, checks keybindings and CLI configuration, asks Ghostty to validate the template rendered for macOS (Linux does not deploy it, so that is the only rendering there is), and probes Hyprland and the configured font. It cleans up afterwards and does **not** run `chezmoi apply` against your existing home directory.

For an SSH/headless shell or Arch CI, run `bash scripts/accept-omarchy --headless`. That mode intentionally does not claim desktop integration. A `RESULT: PASS` only covers checks that ran. Neither mode tests real clipboard round-trips, the physical display, or an SSH reconnect from the Mac to the Omarchy host.

Finish the host acceptance by manually verifying a copy/paste operation in local Ghostty and tmux, and an SSH connection from the Mac into an already-running tmux session on the Omarchy host. Record the results in the PR before labeling the workstation migration 100% complete. Do not paste tokens, clipboard contents or private hostnames into public CI logs.

## Validation and rollback

```sh
chezmoi verify
chezmoi diff
tmux -V
command -v xdg-open
```

Use the backup notes in `~/.cli-workbench-backup/` to restore any overwritten files. This does not revert installed packages or desktop settings; for those, use Omarchy's btrfs snapshots (snapper), the system-level rollback. Never commit private SSH keys, tokens, agent sessions or proxy credentials.

## Coverage boundary

The CI matrix covers macOS, Ubuntu and an Arch Linux container. It does not test the complete Omarchy desktop image, graphics, system sleep, or live SSH/Tailscale connections. Validate those on the Omarchy host before declaring the workstation migration complete.

## Read-only workstation diagnostics

Run `bash scripts/doctor-omarchy` in a local desktop session, or `bash scripts/doctor-omarchy --headless` over SSH, to check required commands and report Wayland/session context. It does not install software or change the machine. The Wayland socket can be absent during SSH access; run from a local Ghostty window to validate desktop integration.

## Manual acceptance checklist

1. On macOS, render Ghostty config with `chezmoi execute-template < home/dot_config/ghostty/config.tmpl`; confirm title-bar and window-state options remain.
2. On Omarchy, apply and confirm `~/.config/ghostty/config` is still Omarchy's own file (this repository does not deploy one there); launch Ghostty and check Nerd Font glyphs.
3. Start an isolated tmux server, verify the effective prefix (see above), project picker, agent overview, clipboard, and URL opener.
4. Open interactive zsh; check `PATH`, completions and required Omarchy commands. Keep Bash login shell until verified.
5. Reattach the Omarchy host's tmux session from the Mac over SSH/Tailscale; verify that Agent processes remain alive.
6. Verify backups and restore a disposable configuration in a test HOME before applying to the real workstation.
