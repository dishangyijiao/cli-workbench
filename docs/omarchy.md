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
sudo pacman -S --needed git chezmoi zsh tmux fzf ripgrep jq neovim zoxide starship ghostty xdg-utils
```

Install the required Nerd Font separately or change the Ghostty `font-family` setting. Install Coding Agents and their credentials separately; this repository deliberately does not manage secrets.

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
chezmoi apply ~/.tmux/scripts ~/.tmux.conf
# Test in an isolated tmux server, leaving existing sessions alone:
tmux -L workbench-test -f ~/.tmux.conf new-session
```

Deploy the remaining targets only after reviewing each diff. **Apply `~/.zshrc` last**: it replaces the existing file. Omarchy shell functions may depend on Bash; initially keep the system login shell unchanged and launch zsh explicitly from your preferred terminal.

## Known platform differences

- Omarchy's tmux prefix may differ from CLI Workbench's `Ctrl+A`. Choose one tmux configuration as authoritative; do not concatenate both.
- The Ghostty config is a chezmoi OS template: macOS retains its title-bar tabs and window restoration, while Linux omits those options. The rendered config is checked on macOS and Linux in CI.
- tmux-fzf-url selects `xdg-open` when available, otherwise `open`. Check the effective `@fzf-url-open` option.
- The Homebrew Brewfile is not an Arch package manifest.
- Validate SSH/Tailscale, clipboard and Wayland integration on the actual host. The Arch CI container validates scripts and chezmoi deployment, but cannot validate a Hyprland desktop session or Ghostty rendering.

## Validation and rollback

```sh
chezmoi verify
chezmoi diff
tmux -V
command -v xdg-open
```

Use the backup notes in `~/.cli-workbench-backup/` to restore any overwritten files. This does not revert installed packages or desktop settings. Never commit private SSH keys, tokens, agent sessions or proxy credentials.

## Coverage boundary

The CI matrix covers macOS, Ubuntu and an Arch Linux container. It does not test the complete Omarchy desktop image, graphics, system sleep, or live SSH/Tailscale connections. Validate those on the SER9 before declaring the workstation migration complete.

## Read-only workstation diagnostics

Run `bash scripts/doctor-omarchy` to check required commands and report Wayland/session context. It does not install software or change the machine. The Wayland socket can be absent during SSH access; run from a local Ghostty window to validate desktop integration.

## Manual acceptance checklist

1. On macOS, render Ghostty config with `chezmoi execute-template < home/dot_config/ghostty/config.tmpl`; confirm title-bar and window-state options remain.
2. On Omarchy, render the same template and confirm those options are absent; launch Ghostty and check Nerd Font glyphs.
3. Start an isolated tmux server, verify `Ctrl+A`, project picker, agent overview, clipboard, and URL opener.
4. Open interactive zsh; check `PATH`, completions and required Omarchy commands. Keep Bash login shell until verified.
5. Reattach the SER9 tmux session from the MacBook over SSH/Tailscale; verify that Agent processes remain alive.
6. Verify backups and restore a disposable configuration in a test HOME before applying to the real workstation.
