# cli-workbench

[![tests](https://github.com/dishangyijiao/cli-workbench/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/dishangyijiao/cli-workbench/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English | [简体中文](README.zh-CN.md)

Keep your command-line environment (zsh, tmux, Ghostty, Git, the Claude Code status line) in **one Git repository**, and make the files your machine actually uses *be* the files in that repository, through symlinks. A few small, tested shell scripts plan, apply, check and diagnose those links safely.

> **What this is:** a personal-dotfiles framework with sensible default configs. You fork it or clone it, edit `config/`, and keep it as your own.
> **What this is not:** a package manager, a one-click installer, or a theme pack. It does not install software and it does not manage secrets.

## Requirements and scope

| | |
|---|---|
| **Platform** | **macOS** is the primary platform (tested on macOS 26, Apple Silicon). The scripts and the zsh and tmux configs also pass the full test suite and the first-run flow on **Ubuntu 24.04** (checked in a container); the Ghostty config and the Homebrew casks are macOS-oriented. Windows is not supported. |
| **Shell** | zsh 5.8 or newer (tested with 5.9). The scripts are bash 3.2 compatible, i.e. the macOS system bash is enough. |
| **tmux** | 3.2 or newer recommended (tested with 3.5a). Older versions still load the config, minus the workspace switcher key. |
| **Required** | `git`, and `zsh` if you use the zsh component (`doctor` reports FAIL without it) |
| **Optional** | `fzf` (0.48+ for the shell integration), `zoxide`, `starship`, `zsh-syntax-highlighting`, `jq` (status line), [Ghostty](https://ghostty.org) and a Nerd Font, Homebrew |

**What it changes on your machine, and nothing else:**

- the symlinks listed in [`links.txt`](links.txt), only when you run `scripts/link <component> --apply`;
- backups of files those links replace, in `~/.cli-workbench-backup/<timestamp>/`, with a `RESTORE` note;
- a zsh completion cache in `~/.cache/zsh/`, once you use the provided `zshrc`.

**What it never does:** delete your files, install software, change anything without `--apply`, or touch files that are not in `links.txt`.

## Quick start

```sh
git clone https://github.com/dishangyijiao/cli-workbench.git ~/dev/cli-workbench   # or your fork; any location works
cd ~/dev/cli-workbench

scripts/bootstrap                  # read-only: check + the plan of what would be linked
scripts/link tmux --apply          # apply ONE component at a time, then verify just that one
scripts/check tmux
```

Components (from `links.txt`):

| Component | Target | Notes |
|---|---|---|
| `tmux`, `tmux-scripts` | `~/.tmux.conf`, `~/.tmux/scripts` | prefix `Ctrl-a`, vi keys, mouse, workspace switcher |
| `zsh` | `~/.zshrc` | replaces your `.zshrc` (backed up, not deleted); move your own tweaks to `local.zsh` first. Installers (nvm, bun, ...) append to `~/.zshrc`, which is this repo's file now: move such lines into `local.zsh` instead of committing them |
| `zsh-autostart` | `~/.config/zsh/tmux-autostart.zsh` | optional tmux session chooser for new tabs, off by default |
| `ghostty` | `~/.config/ghostty/config` | Catppuccin Mocha, Nerd Font, macOS tabs title bar |
| `claude-statusline` | `~/.claude/statusline.sh` | only if you use Claude Code |
| `nvim` | `~/.config/nvim` | optional Neovim setup (lazy.nvim, LSP, Telescope, Git, debugging); plugins install on first launch and need network access. Skip it if you have your own |

Git: the portable settings are not linked, because tools write to `~/.gitconfig`. Include them instead:

```sh
git config --global --add include.path "$PWD/config/git/config"
```

Suggested order and the manual steps (Homebrew tools, tmux plugin manager) are in [`docs/bootstrap.md`](docs/bootstrap.md).

## Defaults you may want to change first

These are opinions, not requirements. Edit the files in `config/`; because they are symlinked, the change is live at once.

- **tmux:** prefix is `Ctrl-a` (not `Ctrl-b`); vi-style copy mode; mouse on; windows numbered from 1. Pane contents are **not** saved to disk by default (that would store anything printed in a pane, tokens included); see the comment next to `@resurrect-capture-pane-contents` to turn it on.
- **zsh:** 50,000-line shared history, case-insensitive completion, `starship`, `zoxide`, `fzf` and `zsh-syntax-highlighting` only if installed.
- **Ghostty:** Catppuccin Mocha and `SauceCodePro Nerd Font Mono` (install the font or change the line).

## Make it yours

- **Per-machine settings** (extra PATH entries, a proxy, turning on the tmux chooser): copy `templates/local.zsh.example` to `~/.config/zsh/local.zsh`. It is not tracked and is loaded last.
- **Secrets**: `templates/secrets.zsh.example` to `~/.config/zsh/secrets.zsh`, mode 600. Never commit it. The repository must never contain keys or tokens.
- **Add another tool:** put its config in `config/<tool>/`, add one line to `links.txt` (`component  path-in-repo  ~/target`), run `scripts/link <component>`, then `--apply`.
- **Neovim:** a ready-made setup ships as the optional `nvim` component. To use your own instead, replace `config/nvim` and keep the `nvim` line in `links.txt`.

## Commands

```sh
scripts/check [component ...]   # fast, read-only: links resolve to the right sources, zsh and shell-script files parse, status line test
                                # (name components to check only their links; the tmux config is loaded by doctor --deep)
scripts/doctor           # adds: tools, PATH duplicates and dead entries, proxy variables, repository state
scripts/doctor --deep    # adds: really starts zsh, tmux and nvim (zsh runs YOUR startup files; tmux uses a private socket; nvim uses your config)
scripts/link [component] [--apply] [--adopt]
tests/run.sh             # the scripts' own tests, including an end-to-end run of this README's quick start in a throwaway HOME
```

Output is `PASS` / `WARN` / `FAIL`. `check` and `doctor` exit non-zero only on `FAIL`.

## Safety model

- `scripts/link` is a **dry run** unless you pass `--apply`.
- An existing regular file is **moved**, not deleted, to `~/.cli-workbench-backup/<timestamp>/`.
- A real directory, or a symlink that points somewhere else, makes `link` **stop** until you read the plan and pass `--adopt` for that component.
- `--apply` checks **every selected component first**: if any would stop, or its source is missing, nothing is changed at all. Once applying has started, a failure is reported and components already applied stay applied.
- If a link cannot be created after the backup, the original file is **put back**, unless something new has appeared at that path meanwhile; then the backup is kept and its location is printed.
- A target that lives inside this repository (including a path that would be created there), or that holds it, is **refused**, even with `--adopt`. Example: `~/.config` symlinked to this repo's `config/`.
- `scripts/bootstrap`, `check` and `doctor` do not modify your files. They may create and remove temporary files in the system temp directory.
- `doctor --deep` really starts programs. It runs **your real zsh startup files** and **your nvim config and data**, so whatever they do (writing files, updating plugins) happens for real; only the cache directory of the supplied `zshrc` is a throwaway one. tmux runs on a private socket.

## Workspace switcher (tmux)

Press `prefix` then `P` (`Ctrl-a P`) for a picker over `~/dev/projects`. Every directory directly under a root is a workspace, opened as one tmux session with the editor on the left and a shell on the right. A directory that is not a repository but contains several (a multi-repo product) is **one** workspace with one window per repository. Choosing an existing workspace only switches to it. It needs tmux 3.2+ and `fzf`.

To scan other directories, uncomment `WORKSPACE_ROOTS` in `config/tmux/tmux.conf`. Details are in the header of `config/tmux/scripts/workspace-switch.sh`.

## Uninstall / restore

The links are ordinary symlinks. To go back, remove a link and move the backup into place; `~/.cli-workbench-backup/<timestamp>/RESTORE` lists every replaced file with its original path.

## Troubleshooting

- Debian/Ubuntu: `compinit: initialization aborted` or "insecure directories" at shell start comes from the system's `/etc/zsh/zshrc`, which runs its own `compinit` before yours when `/usr/share/zsh` has loose permissions. The zshrc here already runs `compinit`, so put `skip_global_compinit=1` in `~/.zshenv` (or fix the permissions, see `compaudit`).
- `FAIL link ...`: run `scripts/link <component>` and read the plan. `STOP` means a real directory or a foreign link is in the way: compare, then `--adopt`.
- tmux config problems: `scripts/doctor --deep` loads it on a private socket.
- More in [`docs/architecture.md`](docs/architecture.md).

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). For security problems, see [SECURITY.md](SECURITY.md) instead of opening a public issue. Changes between versions are in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
