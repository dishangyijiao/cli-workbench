# Bootstrap

Nothing here installs software for you; chezmoi only deploys the files under `home/`.

## Apply order

Look first, then apply one piece at a time. zsh goes last, because it changes every new shell.

```sh
chezmoi init --source "$PWD"                  # once: this clone as the source, plus the backup hook
chezmoi diff                                  # read-only
chezmoi apply ~/.config/ghostty/config
chezmoi apply ~/.tmux/scripts ~/.tmux.conf
chezmoi apply ~/.claude/statusline.sh         # only if you use Claude Code
chezmoi apply ~/.config/git/config
chezmoi apply ~/.config/zsh ~/.zshrc
chezmoi apply ~/.config/nvim                  # optional; skip it if you have your own Neovim config
chezmoi verify && echo "in sync"
```

Before each apply, the hook installed by `init` copies the files it is about to replace to `~/.cli-workbench-backup/<timestamp>/` (with a `RESTORE` note). chezmoi itself keeps no backup, so do run `init`; a hand-written `chezmoi.toml` has no hook.

## Not automated

- Installing Homebrew and the tools: `brew bundle --file=packages/Brewfile`.
- tmux plugins: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`, then press `prefix` + `I` inside tmux. The tmux config works without it.
- Secrets and per-machine settings: copy `templates/*.example` into `~/.config/zsh/` (see `docs/architecture.md`).
