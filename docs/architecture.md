# Architecture

## Source of truth

Git, plain text and chezmoi. Not a GUI's current state, a tmux session or a shell's history.

## Why chezmoi (and copies, not symlinks)

| Approach | Active config vs repo | Fits |
|---|---|---|
| chezmoi (copies) | differs until the next `apply`; `chezmoi diff`/`verify` show the difference | this project |
| symlinks (earlier versions of this repo) | identical by construction | needed a home-grown linker, checker and doctor (about 600 lines of bash plus tests) |

The trade: an edit is no longer live at once (`chezmoi edit --apply`, or edit `home/` and `chezmoi apply`), and files a program rewrites in `$HOME` need `chezmoi re-add`. In return the install, diff, verify and state tracking are chezmoi's job, not this repository's. chezmoi can also grow templates and encrypted files later, if a second machine ever needs them.

## Layout

`.chezmoiroot` contains `home`, so only `home/` is the source tree; `docs/`, `tests/`, `scripts/`, `templates/` and `packages/` are never deployed. Names follow chezmoi: `dot_` becomes `.`, `executable_` sets the executable bit, `private_` makes the directory mode 700 (`~/.config/zsh` holds `secrets.zsh`).

The source directory is wherever the clone lives; `~/.config/chezmoi/chezmoi.toml` sets `sourceDir` (see the README).

## Machine differences

Common settings live in `home/`. Differences between machines live in files chezmoi does not manage, so no config is duplicated:

- `~/.config/zsh/local.zsh`: PATH additions, proxies, opt-in switches (template: `templates/local.zsh.example`)
- `~/.config/zsh/secrets.zsh`: API keys and tokens, mode 600 (template: `templates/secrets.zsh.example`)
- `~/.gitconfig`: identity and credentials; Git also reads the portable part from `~/.config/git/config` by itself

## State

The repository is authoritative. chezmoi's own state (`~/.config/chezmoi/chezmoistate.boltdb`) only records what it wrote last; deleting it is harmless. tmux sessions, editor sessions and GUI settings are runtime state and can be rebuilt.

## Verification layers

| Command | Scope | Side effects |
|---|---|---|
| `chezmoi diff`, `chezmoi status`, `chezmoi verify` | `$HOME` against `home/` | none |
| `chezmoi doctor` | chezmoi's own checks | none |
| `tests/run.sh` | the shell configs, tmux scripts, status line and privacy scanner, against throwaway HOMEs (`chezmoi apply` into a temp directory) | temp files only |
| `scripts/privacy-scan` | secrets, personal paths, e-mail addresses in tracked files | none; also a pre-commit hook and a CI gate |

## Troubleshooting

- zsh behaves differently after a change: `chezmoi diff ~/.zshrc`, then start `zsh -i` in a new terminal.
- tmux config problems: `tmux -L test -f ~/.tmux.conf new-session -d && tmux -L test show-messages`.
- Something was overwritten: chezmoi keeps no backup; restore from your own copy or from Git history of the file's previous source.
