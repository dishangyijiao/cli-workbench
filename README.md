# cli-workbench

[![tests](https://github.com/dishangyijiao/cli-workbench/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/dishangyijiao/cli-workbench/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English | [简体中文](README.zh-CN.md)

Keep your command-line environment (zsh, tmux, Ghostty, Git, the Claude Code status line, optionally Neovim) in **one Git repository** and deploy it with [chezmoi](https://www.chezmoi.io). The repository is a chezmoi source tree: fork it, edit it, run `chezmoi apply`.

> **What this is:** a personal-dotfiles repository with sensible default configs, laid out as a chezmoi source tree. You fork it, edit `home/`, and keep it as your own.
> **What this is not:** a package manager, a one-click installer, or a theme pack. It does not install software and it does not manage secrets.

## Requirements and scope

| | |
|---|---|
| **Platform** | **macOS** is the primary platform (tested on macOS 26, Apple Silicon). The zsh and tmux configs also pass the full test suite and the first-run flow on **Ubuntu 24.04** (checked in a container); the Ghostty config and the Homebrew casks are macOS-oriented. Windows is not supported. |
| **Shell** | zsh 5.8 or newer (tested with 5.9). The helper scripts are bash 3.2 compatible, i.e. the macOS system bash is enough. |
| **tmux** | 3.2 or newer recommended (tested with 3.5a). Older versions still load the config, minus the workspace switcher key. |
| **Required** | `git` and [`chezmoi`](https://www.chezmoi.io/install/) (`brew install chezmoi`) |
| **Optional** | `fzf` (0.48+ for the shell integration), `zoxide`, `starship`, `zsh-syntax-highlighting`, `jq` (status line), [Ghostty](https://ghostty.org) and a Nerd Font, Homebrew |

**What it changes on your machine:** exactly the files under [`home/`](home) that chezmoi deploys (the table below), plus a zsh completion cache in `~/.cache/zsh/`. **chezmoi does not back up files it replaces.** Always run `chezmoi diff` first, and copy away anything you would miss before `apply`.

## Quick start

```sh
brew install chezmoi
git clone https://github.com/dishangyijiao/cli-workbench.git ~/dev/cli-workbench   # or your fork; any location works

mkdir -p ~/.config/chezmoi
printf 'sourceDir = "%s"\n' ~/dev/cli-workbench > ~/.config/chezmoi/chezmoi.toml  # use this clone as the source

chezmoi diff                       # read-only: what would change in $HOME
chezmoi apply ~/.tmux.conf         # apply ONE file first, then look at the result
chezmoi apply                      # then everything
```

Or let chezmoi do the clone: `chezmoi init --apply <your-github-user>/cli-workbench`.

What gets deployed (the layout follows [chezmoi's naming](https://www.chezmoi.io/reference/source-state-attributes/): `dot_` becomes `.`, `executable_` sets the mode, `private_` makes the directory 700):

| Source in `home/` | Target | Notes |
|---|---|---|
| `dot_tmux.conf`, `dot_tmux/scripts/` | `~/.tmux.conf`, `~/.tmux/scripts` | prefix `Ctrl-a`, vi keys, mouse, workspace switcher |
| `dot_zshrc`, `dot_config/private_zsh/` | `~/.zshrc`, `~/.config/zsh/{path,tmux-autostart}.zsh` | **replaces your `.zshrc`**; move your own tweaks to `~/.config/zsh/local.zsh` first. Installers (nvm, bun, ...) append to `~/.zshrc`; `chezmoi diff` shows that, so move such lines into `local.zsh` |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` | Catppuccin Mocha, Nerd Font, macOS tabs title bar |
| `dot_claude/executable_statusline.sh` | `~/.claude/statusline.sh` | only if you use Claude Code |
| `dot_config/git/config` | `~/.config/git/config` | portable Git settings; Git reads this file by itself, and `~/.gitconfig` (identity, credentials) stays yours |
| `dot_config/nvim/` | `~/.config/nvim` | optional Neovim setup (lazy.nvim, LSP, Telescope, Git, debugging); plugins install on first launch and need network access. Delete the directory from your fork if you have your own |

Suggested order and the manual steps (Homebrew tools, tmux plugin manager) are in [`docs/bootstrap.md`](docs/bootstrap.md).

## Defaults you may want to change first

These are opinions, not requirements. Edit the files in `home/` and run `chezmoi apply` (or `chezmoi edit --apply ~/.tmux.conf`).

- **tmux:** prefix is `Ctrl-a` (not `Ctrl-b`); vi-style copy mode; mouse on; windows numbered from 1. Pane contents are **not** saved to disk by default (that would store anything printed in a pane, tokens included); see the comment next to `@resurrect-capture-pane-contents` to turn it on.
- **zsh:** 50,000-line shared history, case-insensitive completion, `starship`, `zoxide`, `fzf` and `zsh-syntax-highlighting` only if installed.
- **Ghostty:** Catppuccin Mocha and `SauceCodePro Nerd Font Mono` (install the font or change the line).

## Make it yours

- **Per-machine settings** (extra PATH entries, a proxy, turning on the tmux chooser): copy `templates/local.zsh.example` to `~/.config/zsh/local.zsh`. chezmoi does not manage it and it is loaded last.
- **Secrets**: `templates/secrets.zsh.example` to `~/.config/zsh/secrets.zsh`, mode 600. Never commit it. The repository must never contain keys or tokens.
- **Add another tool:** `chezmoi add ~/.config/<tool>/config` copies the file into `home/`; commit it.
- **Files a program rewrites** (for example `lazy-lock.json` after `:Lazy update`): the copy in `$HOME` changes, the repository does not. `chezmoi diff` shows it; `chezmoi re-add` pulls it back into `home/`.
- **Neovim:** to use your own setup instead, delete `home/dot_config/nvim` from your fork.

## Commands

```sh
chezmoi diff | status | verify   # what differs between home/ and $HOME (verify exits non-zero if anything does)
chezmoi doctor                   # chezmoi's own health check
tests/run.sh                     # the repository's tests, including an end-to-end run of this quick start in a throwaway HOME
scripts/privacy-scan [--all]     # secrets, personal paths and e-mail addresses in staged (or all tracked) files
```

## Safety model

- `chezmoi diff` and `chezmoi apply --dry-run` change nothing.
- **chezmoi overwrites** a file whose content differs from the source, without a backup. Read the diff first. (A file chezmoi wrote earlier and you edited since makes it stop and ask instead.)
- It only touches the targets in the table above, and it deletes nothing unless you ask for it (`chezmoi destroy`).
- `privacy-scan` runs in the pre-commit hook and in CI, so keys, tokens, personal paths and e-mail addresses do not reach a public fork by accident.

## Workspace switcher (tmux)

Press `prefix` then `P` (`Ctrl-a P`) for a picker over `~/dev/projects`. Every directory directly under a root is a workspace, opened as one tmux session with the editor on the left and a shell on the right. A directory that is not a repository but contains several (a multi-repo product) is **one** workspace with one window per repository. Choosing an existing workspace only switches to it. It needs tmux 3.2+ and `fzf`.

To scan other directories, uncomment `WORKSPACE_ROOTS` in `home/dot_tmux.conf`. Details are in the header of `home/dot_tmux/scripts/executable_workspace-switch.sh`.

## Uninstall / restore

chezmoi leaves ordinary files behind. Restore your own copies (made before `apply`), or delete what you no longer want. `chezmoi unmanage <target>` stops managing one file.

## Troubleshooting

- Debian/Ubuntu: `compinit: initialization aborted` or "insecure directories" at shell start comes from the system's `/etc/zsh/zshrc`, which runs its own `compinit` before yours when `/usr/share/zsh` has loose permissions. The zshrc here already runs `compinit`, so put `skip_global_compinit=1` in `~/.zshenv` (or fix the permissions, see `compaudit`).
- `chezmoi: ... has changed since chezmoi last wrote it`: you edited the deployed file. Run `chezmoi diff`, then `chezmoi re-add` (keep your edit) or `chezmoi apply --force` (take the repository's).
- tmux config problems: `tmux -L test -f ~/.tmux.conf new-session -d` loads it on a private socket; `tmux -L test show-messages` prints errors.
- More in [`docs/architecture.md`](docs/architecture.md).

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). For security problems, see [SECURITY.md](SECURITY.md) instead of opening a public issue. Changes between versions are in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
