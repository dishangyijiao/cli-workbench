# cli-workbench

English | [简体中文](README.zh-CN.md)

Keep your command-line environment (zsh, tmux, Ghostty, Git, the Claude Code status line) in **one Git repository**, and make the files your machine actually uses *be* the files in that repository, through symlinks. A few small, tested shell scripts plan, apply, check and diagnose those links safely.

> **What this is:** a personal-dotfiles framework with sensible default configs. You fork it or clone it, edit `config/`, and keep it as your own.
> **What this is not:** a package manager, a one-click installer, or a theme pack. It does not install software and it does not manage secrets.

## Requirements and scope

| | |
|---|---|
| **Platform** | **macOS** is the primary platform (tested on macOS 15, Apple Silicon). The scripts and the zsh and tmux configs also pass the full test suite and the first-run flow on **Ubuntu 24.04** (checked in a container); the Ghostty config and the Homebrew casks are macOS-oriented. Windows is not supported. |
| **Shell** | zsh 5.8 or newer (tested with 5.9). The scripts are bash 3.2 compatible, i.e. the macOS system bash is enough. |
| **tmux** | 3.2 or newer recommended (tested with 3.5a). Older versions still load the config, minus the workspace switcher key. |
| **Required** | `git` |
| **Optional** | `fzf` (0.48+ for the shell integration), `zoxide`, `starship`, `jq` (status line), [Ghostty](https://ghostty.org) and a Nerd Font, Homebrew |

**What it changes on your machine, and nothing else:**

- the symlinks listed in [`links.txt`](links.txt), only when you run `scripts/link <component> --apply`;
- backups of files those links replace, in `~/.cli-workbench-backup/<timestamp>/`, with a `RESTORE` note;
- a zsh completion cache in `~/.cache/zsh/`, once you use the provided `zshrc`.

**What it never does:** delete your files, install software, change anything without `--apply`, or touch files that are not in `links.txt`.

## Quick start

```sh
git clone <your-fork-or-this-repo-url> ~/dev/cli-workbench      # any location works
cd ~/dev/cli-workbench

scripts/bootstrap                  # read-only: check + the plan of what would be linked
scripts/link tmux --apply          # apply ONE component at a time, then verify
scripts/check
```

Components (from `links.txt`):

| Component | Target | Notes |
|---|---|---|
| `tmux`, `tmux-scripts` | `~/.tmux.conf`, `~/.tmux/scripts` | prefix `Ctrl-a`, vi keys, mouse, workspace switcher |
| `zsh` | `~/.zshrc` | replaces your `.zshrc` (backed up, not deleted); move your own tweaks to `local.zsh` first |
| `zsh-autostart` | `~/.config/zsh/tmux-autostart.zsh` | optional tmux session chooser for new tabs, off by default |
| `ghostty` | `~/.config/ghostty/config` | Catppuccin Mocha, Nerd Font, macOS tabs title bar |
| `claude-statusline` | `~/.claude/statusline.sh` | only if you use Claude Code |

Git: the portable settings are not linked, because tools write to `~/.gitconfig`. Include them instead:

```sh
git config --global --add include.path "$PWD/config/git/config"
```

Suggested order and the manual steps (Homebrew tools, tmux plugin manager) are in [`docs/bootstrap.md`](docs/bootstrap.md).

## Defaults you may want to change first

These are opinions, not requirements. Edit the files in `config/`; because they are symlinked, the change is live at once.

- **tmux:** prefix is `Ctrl-a` (not `Ctrl-b`); vi-style copy mode; mouse on; windows numbered from 1. Pane contents are **not** saved to disk by default (that would store anything printed in a pane, tokens included); see the comment next to `@resurrect-capture-pane-contents` to turn it on.
- **zsh:** 50,000-line shared history, case-insensitive completion, `starship` and `zoxide` and `fzf` only if installed.
- **Ghostty:** Catppuccin Mocha and `SauceCodePro Nerd Font Mono` (install the font or change the line).

## Make it yours

- **Per-machine settings** (extra PATH entries, a proxy, turning on the tmux chooser): copy `templates/local.zsh.example` to `~/.config/zsh/local.zsh`. It is not tracked and is loaded last.
- **Secrets**: `templates/secrets.zsh.example` to `~/.config/zsh/secrets.zsh`, mode 600. Never commit it. The repository must never contain keys or tokens.
- **Add another tool:** put its config in `config/<tool>/`, add one line to `links.txt` (`component  path-in-repo  ~/target`), run `scripts/link <component>`, then `--apply`.
- **Neovim:** no editor config is shipped. Add your own `config/nvim` and uncomment the `nvim` line in `links.txt`.

## Commands

```sh
scripts/check            # fast, read-only: links resolve to the right sources, files parse, status line test
scripts/doctor           # adds: tools, PATH duplicates and dead entries, proxy variables, repository state
scripts/doctor --deep    # adds: really starts zsh, tmux and nvim (zsh and tmux are isolated; nvim uses your real config)
scripts/link [component] [--apply] [--adopt]
tests/run.sh             # the scripts' own tests, including an end-to-end run of this README's quick start in a throwaway HOME
```

Output is `PASS` / `WARN` / `FAIL`. `check` and `doctor` exit non-zero only on `FAIL`.

## Safety model

- `scripts/link` is a **dry run** unless you pass `--apply`.
- An existing regular file is **moved**, not deleted, to `~/.cli-workbench-backup/<timestamp>/`.
- A real directory, or a symlink that points somewhere else, makes `link` **stop** until you read the plan and pass `--adopt` for that component.
- `--apply` is **all-or-nothing**: if any selected component would stop (or its source is missing), nothing is changed at all.
- If a link cannot be created after the backup, the original file is **put back** automatically.
- A target that is part of this repository, or that contains it (for example `~/.config` symlinked to `config/`), is **refused**, even with `--adopt`.
- `scripts/bootstrap`, `check` and `doctor` do not modify your files. They may create and remove temporary files in the system temp directory.
- `doctor --deep` really starts programs. zsh runs with a throwaway cache directory and tmux on a private socket. **nvim uses your real config and data**, so a plugin manager may update its own files.

## Workspace switcher (tmux)

Press `prefix` then `P` (`Ctrl-a P`) for a picker over `~/dev/projects`. Every directory directly under a root is a workspace, opened as one tmux session with the editor on the left and a shell on the right. A directory that is not a repository but contains several (a multi-repo product) is **one** workspace with one window per repository. Choosing an existing workspace only switches to it. It needs tmux 3.2+ and `fzf`.

To scan other directories, uncomment `WORKSPACE_ROOTS` in `config/tmux/tmux.conf`. Details are in the header of `config/tmux/scripts/workspace-switch.sh`.

## Uninstall / restore

The links are ordinary symlinks. To go back, remove a link and move the backup into place; `~/.cli-workbench-backup/<timestamp>/RESTORE` lists every replaced file with its original path.

## Troubleshooting

- `FAIL link ...`: run `scripts/link <component>` and read the plan. `STOP` means a real directory or a foreign link is in the way: compare, then `--adopt`.
- tmux config problems: `scripts/doctor --deep` loads it on a private socket.
- More in [`docs/architecture.md`](docs/architecture.md).

## Contributing

Issues and pull requests are welcome. Please keep scripts bash 3.2 compatible, add a test for new behaviour, and run `tests/run.sh` before sending. A GitHub Actions workflow (`.github/workflows/tests.yml`) runs the suite on macOS and Ubuntu for every push and pull request. Do not include personal paths, names or credentials.

## License

[MIT](LICENSE)
