# Architecture

## Source of truth

Git, plain text and scripts. Not a GUI's current state, a tmux session or a shell's history.

## Why symlinks (not copies, not generated files)

| Approach | Active config vs repo | Fits |
|---|---|---|
| symlink | identical by construction; an edit is live at once | this project |
| copy (as many dotfile managers do) | drifts until the next `apply` | not used |
| generate from templates | needs re-generation after every change | only for files that must be rendered (none yet) |

## Components

`links.txt` maps `component -> path in the repo -> target path`. `scripts/link` applies it one component at a time:

- the default is a dry run that only prints the plan;
- `--apply` is all-or-nothing: if any selected entry would stop, nothing is changed. It creates the links; an existing regular file is moved to `~/.cli-workbench-backup/<timestamp>/`, never deleted, and put back if the link cannot be created;
- a real directory, or a symlink that points somewhere else, is a **STOP** case: nothing is touched until you read the plan and pass `--adopt` for that component;
- a target that is part of the repository, or contains it, is always refused;

Scripts find the repository from their own location, so the clone can live anywhere. Only the links themselves record where it is.

## Machine differences

Common settings live in the repo. Differences between machines live in untracked local files, so no config is duplicated:

- `~/.config/zsh/local.zsh`: PATH additions, proxies, opt-in switches (template: `templates/local.zsh.example`)
- `~/.config/zsh/secrets.zsh`: API keys and tokens, mode 600 (template: `templates/secrets.zsh.example`)
- `~/.gitconfig`: identity and credentials; it includes `config/git/config` for the portable part

## State

The repository and the filesystem are authoritative. tmux sessions, editor sessions and GUI settings are runtime state and can be rebuilt.

## Verification layers

| Command | Scope | Side effects |
|---|---|---|
| `scripts/check` | links resolve to the declared sources, shell and tmux files parse, the status line test | none, read-only |
| `scripts/doctor` | adds tool availability, PATH duplicates and dead entries, proxy variables, repository state | none, read-only |
| `scripts/doctor --deep` | starts zsh, tmux and nvim for real. zsh uses a throwaway cache dir; tmux a private socket with plugins stripped; **nvim uses your real config and data** | none for zsh and tmux; a plugin manager may update nvim's own files |
| `tests/run.sh` | the scripts themselves, against throwaway fixtures | temp files only |

## Troubleshooting

- `FAIL link X`: run `scripts/link X` and read the plan. STOP means a real directory or a foreign link is in the way: compare, then `--adopt`.
- zsh behaves differently after a change: `scripts/zsh-snapshot ~/.zshrc > /tmp/after` and diff it against a snapshot taken before, in the same environment.
- tmux config problems: `scripts/doctor --deep` loads it on a private socket.
- Restore anything: see `RESTORE` in the newest `~/.cli-workbench-backup/*/`.
