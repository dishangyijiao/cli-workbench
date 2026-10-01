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

`home/.chezmoi.toml.tmpl` is what `chezmoi init --source <clone>` renders into `~/.config/chezmoi/chezmoi.toml`: `sourceDir` (the clone can live anywhere) and the `hooks.apply.pre` backup hook. It lives under `home/` because that is the source root; chezmoi does not deploy it.

## Backup before apply

chezmoi overwrites differing files and keeps no copy. `scripts/backup-before-apply` is configured as the `apply.pre` hook (a `run_before_` script would not do: chezmoi skips scripts for `chezmoi apply <one file>` and for `--dry-run`, but runs hooks). It asks `chezmoi status` which existing files an apply would replace, copies them to `~/.cli-workbench-backup/<timestamp>/` (mode 700, paths mirrored, symlinks preserved, a `RESTORE` note), and exits non-zero on any failure, which makes chezmoi abort. It does nothing for `--dry-run` or when nothing would change. Because it ignores which targets you named, applying one file may back up a few more.

## Agent instructions

Claude Code, Codex and Gemini CLI read `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` and `~/.gemini/GEMINI.md`. The three targets are one-line templates (`{{ template "agent-instructions.md" . }}`) over `home/.chezmoitemplates/agent-instructions.md`, so the text has exactly one source. That template appends `~/.config/cli-workbench/agent-instructions.local.md` when it exists (chezmoi's `stat`/`include`): the personal layer, never tracked. Rendered files are not re-addable; edit the source. The agents' own settings and state (`settings.json`, `config.toml`, `auth.json`, histories, sessions) are out of scope on purpose, and `tests/defaults.test.sh` fails if such files enter `home/`.

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
| `scripts/backup-before-apply` | the pre-apply hook; tested in `tests/backup.test.sh` | writes only under `~/.cli-workbench-backup/` |
| `tests/run.sh` | the shell configs, tmux scripts, status line and privacy scanner, against throwaway HOMEs (`chezmoi apply` into a temp directory) | temp files only |
| `scripts/privacy-scan` | secrets, personal paths, e-mail addresses in tracked files | none; also a pre-commit hook and a CI gate |

## Troubleshooting

- zsh behaves differently after a change: `chezmoi diff ~/.zshrc`, then start `zsh -i` in a new terminal.
- tmux config problems: `tmux -L test -f ~/.tmux.conf new-session -d && tmux -L test show-messages`.
- Something was overwritten: `~/.cli-workbench-backup/<timestamp>/RESTORE` has the command. No backup there means `chezmoi init` was never run on this machine (the hook comes from it).
