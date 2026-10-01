# Bootstrap

Nothing here installs software for you; chezmoi only deploys the files under `home/`.

## Apply order

Look first, then apply one piece at a time. zsh goes last, because it changes every new shell.

```sh
chezmoi diff                                  # read-only; copy away anything you would miss
chezmoi apply ~/.config/ghostty/config
chezmoi apply ~/.tmux/scripts ~/.tmux.conf
chezmoi apply ~/.claude/statusline.sh         # only if you use Claude Code
chezmoi apply ~/.config/git/config
chezmoi apply ~/.config/zsh ~/.zshrc
chezmoi apply ~/.config/nvim                  # optional; skip it if you have your own Neovim config
chezmoi verify && echo "in sync"
```

chezmoi replaces a differing file without a backup. If you want one, copy the file first (`cp ~/.zshrc ~/.zshrc.bak`).

## Not automated

- Installing Homebrew and the tools: `brew bundle --file=packages/Brewfile`.
- tmux plugins: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`, then press `prefix` + `I` inside tmux. The tmux config works without it.
- Secrets and per-machine settings: copy `templates/*.example` into `~/.config/zsh/` (see `docs/architecture.md`).
