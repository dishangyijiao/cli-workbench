# Bootstrap

`scripts/bootstrap` is read-only: it runs `check` and prints the `link` plan. It installs nothing and never passes `--apply`.

## Apply order

Apply one component at a time and run `scripts/check <component>` after each. zsh goes last, because it changes every new shell.

```sh
scripts/link ghostty --apply
scripts/link tmux-scripts --apply
scripts/link tmux --apply
scripts/link claude-statusline --apply     # only if you use Claude Code
scripts/link zsh-autostart --apply
scripts/link zsh --apply
scripts/link nvim --apply                  # optional; skip it if you have your own Neovim config
scripts/check
```

If a target already exists as a real directory or as a link to somewhere else, `link` stops and tells you. Read the plan, then add `--adopt` for that one component.

## Not automated

- Installing Homebrew and the tools: `brew bundle --file=packages/Brewfile`.
- tmux plugins: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`, then press `prefix` + `I` inside tmux. The tmux config works without it.
- The Git include (the portable settings are not linked, because tools write to `~/.gitconfig`):
  `git config --global --add include.path "$PWD/config/git/config"`
- Secrets and per-machine settings: copy `templates/*.example` into `~/.config/zsh/` (see `docs/architecture.md`).
