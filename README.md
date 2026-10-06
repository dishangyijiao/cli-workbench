# cli-workbench

[![tests](https://github.com/dishangyijiao/cli-workbench/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/dishangyijiao/cli-workbench/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English | [简体中文](README.zh-CN.md)

**A terminal workbench for AI coding agents.** Claude Code, Codex, Gemini CLI, Grok CLI and the like are command-line programs that read and write plain text, so the best place to run them is a terminal you control: tmux sessions per project, an editor beside the agent, ripgrep, fzf and jq for text, and every setting in a Git repository you can read, diff and fork. This repository is that environment, deployed with [chezmoi](https://www.chezmoi.io).

```
  prefix + P  ->  pick a project  ->  one tmux session, one window per repository
 ┌─────────────────┬─────────────────┐
 │                 │  claude / codex │   the first installed agent starts here,
 │  nvim           │  gemini / grok  │   in the project's directory
 │                 ├─────────────────┤
 │                 │  shell          │
 └─────────────────┴─────────────────┘
```

## What makes it a workbench, not just dotfiles

| | |
|---|---|
| **Project → session, agent included** | A directory under `~/dev/projects` is a workspace. A folder holding several repositories is **one** workspace with a window per repository, each with its own agent pane. Nothing to register: it is discovered from the directory tree. Auto-detects `claude`, `codex`, `gemini`, `grok` (extend the list with `WORKSPACE_SWITCH_AGENTS`, pick one with `WORKSPACE_SWITCH_AGENT`, turn off with `none`). |
| **Plain text all the way down** | Settings, history, notes and agent instructions are files. `rg`, `fzf`, `jq`, `nvim` and `git` are the tools; there is no GUI state and no database to lose. **One instruction text is deployed to every agent** (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`), with your private rules appended from an untracked file. |
| **Safe to make public** | Agents need API keys, and keys leak through dotfiles. `scripts/privacy-scan` runs as a pre-commit hook and again in CI, and recognises Anthropic (Claude), OpenAI, Google (Gemini) and xAI (Grok) keys, GitHub and AWS tokens, private keys, personal paths and e-mail addresses. A pre-push hook scans commit metadata (author, committer, message) too. tmux pane contents are not saved to disk by default. Secrets live in an untracked file. |
| **Reversible** | Before every `chezmoi apply`, the files it would replace are backed up to `~/.cli-workbench-backup/` with a restore note. |
| **The promises are tested** | The quick start below is run end to end in a throwaway home directory on macOS and Ubuntu. The agent pane (with stand-in agents), the backup and the privacy scanner each have their own tests. |

**Agent-specific today:** the workspace switcher starts any of the four agents; the shared instruction text reaches Claude Code, Codex and Gemini CLI (Grok CLI is not wired up: the location of its instruction file is not known); the status line (`~/.claude/statusline.sh`) and the mods (below) are for Claude Code only. Full agent settings files are deliberately not tracked. Codex's portable UI preferences are merged into its local configuration, see below. The agents themselves are not installed by this repository.

> **What this is:** a personal-dotfiles repository laid out as a chezmoi source tree. You fork it, edit `home/`, and keep it as your own.
>
> **What this is not:** a package manager, a one-click installer, a theme pack, or an agent framework. It does not install software and it does not manage secrets.

## Requirements and scope

| | |
|---|---|
| **Platform** | **macOS** is the primary platform (tested on macOS 26, Apple Silicon). The zsh and tmux configs also pass the full test suite and the first-run flow on **Ubuntu 24.04** (checked in a container); the Ghostty config and the Homebrew casks are macOS-oriented. Windows is not supported. |
| **Shell** | zsh 5.8 or newer (tested with 5.9). The helper scripts are bash 3.2 compatible, i.e. the macOS system bash is enough. |
| **tmux** | 3.2 or newer recommended (tested with 3.5a). Older versions still load the config, minus the workspace switcher key. |
| **Required** | `git` and [`chezmoi`](https://www.chezmoi.io/install/) (`brew install chezmoi`) |
| **Optional** | `fzf` (0.48+ for the shell integration), `zoxide`, `starship`, `zsh-syntax-highlighting`, `jq` (status line), `translate-shell` (the translation popup), [Ghostty](https://ghostty.org) and a Nerd Font, Homebrew |

**What it changes on your machine:** exactly the files under [`home/`](home) that chezmoi deploys (the table below), a zsh completion cache in `~/.cache/zsh/`, and backups of the files it replaces in `~/.cli-workbench-backup/<timestamp>/` (chezmoi itself keeps none; see Safety model).

## Quick start

```sh
brew install chezmoi
git clone https://github.com/dishangyijiao/cli-workbench.git ~/dev/cli-workbench   # or your fork; any location works

chezmoi init --source ~/dev/cli-workbench   # use this clone as the source, and install the backup hook (below)

chezmoi diff                       # read-only: what would change in $HOME
chezmoi apply ~/.tmux.conf         # apply ONE file first, then look at the result
chezmoi apply                      # then everything
```

Or let chezmoi do the clone: `chezmoi init <your-github-user>/cli-workbench`, then the same `diff` and `apply`.

What gets deployed (the layout follows [chezmoi's naming](https://www.chezmoi.io/reference/source-state-attributes/): `dot_` becomes `.`, `executable_` sets the mode, `private_` makes the directory mode 700):

| Source in `home/` | Target | Notes |
|---|---|---|
| `dot_tmux.conf`, `dot_tmux/scripts/` | `~/.tmux.conf`, `~/.tmux/scripts` | prefix `Ctrl-a`, vi keys, mouse, workspace switcher with the agent pane |
| `dot_zshrc`, `dot_config/private_zsh/` | `~/.zshrc`, `~/.config/zsh/{path,tmux-autostart}.zsh` | **replaces your `.zshrc`**; move your own tweaks to `~/.config/zsh/local.zsh` first. Installers (nvm, bun, ...) append to `~/.zshrc`; `chezmoi diff` shows that, so move such lines into `local.zsh` |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` | Catppuccin Mocha, Nerd Font, macOS tabs title bar |
| `dot_claude/executable_statusline.sh` | `~/.claude/statusline.sh` | the Claude Code status line (project, branch, model, context, cost, rate limits); only if you use Claude Code |
| `dot_claude/workbench-mods/` | `~/.claude/workbench-mods/` | two Claude Code mods (`chezmoi-guard`, `reply-polish`) as a local marketplace; deployed, not installed: see "Claude Code mods" |
| `dot_codex/modify_private_config.toml` | `~/.codex/config.toml` | merge portable status-line and completion-bell preferences; preserve other local values |
| `.chezmoitemplates/agent-instructions.md`, `dot_claude/CLAUDE.md.tmpl`, `dot_codex/AGENTS.md.tmpl`, `dot_gemini/GEMINI.md.tmpl` | `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md` | the same short text for every agent: how this workbench works (config lives in the repo, secrets stay out, one tmux session per project). Your own rules: see "Agent instructions" |
| `dot_config/git/config` | `~/.config/git/config` | portable Git settings; Git reads this file by itself, and `~/.gitconfig` (identity, credentials) stays yours |
| `dot_config/nvim/` | `~/.config/nvim` | optional Neovim setup (lazy.nvim, LSP, Telescope, Git, debugging; no AI plugin: agents run in their own pane); plugins install on first launch and need network access. Delete the directory from your fork if you have your own |

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
scripts/privacy-scan [--all]     # secrets, personal paths and e-mail addresses in staged (or all tracked) files, or in commit metadata (--commits)
scripts/lint-shell               # shellcheck (warning level and above) over every bash/sh script in the repository
```

## Safety model

- `chezmoi diff` and `chezmoi apply --dry-run` change nothing.
- **Backup before every apply.** chezmoi overwrites a differing file without keeping a copy. `chezmoi init` installs a hook ([`scripts/backup-before-apply`](scripts/backup-before-apply)) that copies every file the apply is about to replace, including files you edited after chezmoi wrote them, to `~/.cli-workbench-backup/<timestamp>/` first. Directory mode 700, symlinks kept as symlinks, a `RESTORE` note with one copy-paste command per file. If nothing would change, nothing is created. If the backup fails, the apply is refused. `--dry-run` has no side effects.
- The hook is part of the config `chezmoi init` writes. If you only create `chezmoi.toml` by hand, or run `chezmoi apply --source ...` without having run `init`, there is **no** backup.
- It only touches the targets in the table above, and it deletes nothing unless you ask for it (`chezmoi destroy`).
- `scripts/privacy-scan` guards what you commit; see "Safe to make public" above.

## Agent instructions

Claude Code, Codex and Gemini CLI each read a plain-text instruction file from their home directory. Here they are generated from **one** source, `home/.chezmoitemplates/agent-instructions.md`, so the agents get the same facts about the machine.

- **Your own rules** go in `~/.config/cli-workbench/agent-instructions.local.md`. It is not tracked, so personal preferences never reach a public fork. It is appended after the shared text in all three files. Remove the file and the next `chezmoi apply` removes its text.
- **Existing files:** your current `~/.claude/CLAUDE.md` (and the others) are replaced on `apply` and backed up first. Move their content into the local file beforehand if you want to keep it as it is.
- **Edit the source, not the deployed file.** Text that a tool appends to `~/.claude/CLAUDE.md` is overwritten at the next apply. The generated files cannot be pulled back with `chezmoi re-add`.
- **Not tracked as complete files, on purpose:** `settings.json`, `config.toml`, `auth.json`, histories, sessions and databases. They hold machine paths, proxies and credentials, and the tools rewrite them. A test fails if such a file appears under `home/`.
- To publish your own principles, put them in the shared source in your fork, not in the untracked local file.

## Portable Codex preferences

`home/dot_codex/modify_private_config.toml` merges five UI settings into `~/.codex/config.toml`: the status line (model, directory, session name, five-hour and weekly remaining limits), status-line colors, and completion notifications using a terminal bell regardless of focus. With the existing tmux bell settings, Ghostty can mark the background tab with a bell.

On a new machine, install Codex separately and run the usual `chezmoi init` / `chezmoi apply` setup, then sign in to Codex. The configuration is created if absent. Existing model choices, local paths, notification commands, project trust, and other settings are preserved; credentials and sessions are not migrated. Restart an existing Codex CLI after applying (use `codex resume --last` to continue).

Edit the merge template to change these shared preferences. Changes to these five settings made inside Codex are replaced by the next apply. Do not use `chezmoi add` or `re-add` to copy the full local file into the repository. When values need changing, the TOML is reserialized, so comments and formatting are lost; matching files remain unchanged. The existing pre-apply backup hook keeps the original before replacement. Invalid TOML stops the merge without overwriting the file.

## Claude Code mods

A *mod* is a Claude Code plugin whose behavior is a small TypeScript file that Claude Code calls when something happens: a tool is about to run, a reply is about to be drawn. This repository ships two, as a local *marketplace* (a folder Claude Code installs plugins from) in `home/dot_claude/workbench-mods/`:

| Mod | What it does |
|---|---|
| `chezmoi-guard` | Refuses `Edit`, `Write` and `NotebookEdit` on a file chezmoi deploys (`~/.zshrc`, `~/.tmux.conf`, ...) and names the source file to edit instead, so the next `chezmoi apply` cannot overwrite the change. Shows a line above the prompt while the deployed files differ from the source (`chezmoi status`). It cannot see edits made through Bash (`sed -i`, `> file`). If chezmoi is missing or fails, it blocks nothing. |
| `reply-polish` | Lays out the assistant's replies for a wide terminal. The text is one column, at most 80 cells (about 40 Chinese characters) and at most 72% of the window, left-aligned and centered on the screen. Headings are bold, the first two levels in cyan; lists use `•` and `◦`; a table is drawn with box lines when it fits the column and becomes a list when it does not; lines are cut so that a number stays with its unit and closing punctuation never starts a line; a code block longer than 30 lines is shortened to 12. Only the drawing changes: the stored reply, and `ctrl+o`, keep the original. |

**Install once per machine** (needs Claude Code 2.1.287 or later; `chezmoi apply` only deploys the files, it does not install anything):

```sh
chezmoi apply                                                   # deploys ~/.claude/workbench-mods
claude plugin marketplace add ~/.claude/workbench-mods
claude plugin install chezmoi-guard@cli-workbench --scope user
claude plugin install reply-polish@cli-workbench --scope user
```

Then restart Claude Code, or run `/reload-plugins` in a running session.

- **Change a mod:** edit it under `home/dot_claude/workbench-mods/`, run `chezmoi apply`, then `/reload-plugins`. A marketplace that is a folder is read from the folder itself, so no version bump is needed. `claude plugin disable <name>` turns one off, `claude plugin uninstall <name>` removes it.
- **Tests:** `tests/mods.test.sh` always checks the layout of the marketplace. With Claude Code installed it also runs `claude plugin validate` and each mod's own tests (`claude plugin test`); without it that part is skipped.
- **Trust:** a mod sees every tool call and reply and runs with your permissions. Read the source before you install it; each mod is a few hundred lines.
- **Stability:** the mods API is early access and changes between releases. These mods were built and tested with Claude Code 2.1.289. Mods do not load under `--safe-mode` or `--bare`.
- **Not tracked on purpose:** the type declarations Claude Code writes into a mod's `.claude-plugin/types/` when it loads the mod.

## Workspace switcher (tmux)

Press `prefix` then `P` (`Ctrl-a P`) for a picker over `~/dev/projects`. Every directory directly under a root is a workspace, opened as one tmux session: the editor on the left, on the right an AI agent over a shell. A directory that is not a repository but contains several (a multi-repo product) is **one** workspace with one window per repository. Choosing an existing workspace only switches to it. It needs tmux 3.2+ and `fzf`.

- **Agent pane:** the first installed of `claude codex gemini grok` is started in the project directory. If none is installed, the window has just the editor and a shell. `WORKSPACE_SWITCH_AGENT="claude --continue"` picks one (with arguments), `none` turns it off, `WORKSPACE_SWITCH_AGENTS="aider claude"` changes the candidates and their order. Set these with `set-environment -g` in `home/dot_tmux.conf`, next to `WORKSPACE_ROOTS`.
- **Roots:** uncomment `WORKSPACE_ROOTS` in `home/dot_tmux.conf` to scan other directories.
- Details are in the header of `home/dot_tmux/scripts/executable_workspace-switch.sh`.

## Translate what you select (tmux)

Select some English text with the mouse (or `v` ... `y` in copy mode), then press `prefix` then `t` (`Ctrl-a t`). A popup shows a translation, so you do not leave the pane you are reading. One word gives a dictionary entry; anything longer gives its translation. Close the popup with `q`.

- **Needs:** tmux 3.2+ and `translate-shell` (`brew install translate-shell`; without it the popup says so).
- **Privacy:** the selected text is sent to the translation service (Google by default; if that fails, Bing is asked once). Do not use it on text you may not send out.
- **Language:** `LOOKUP_LANG` sets the target language (default `zh-CN`). Details are in the header of `home/dot_tmux/scripts/executable_lookup.sh`.

## Uninstall / restore

Restore from `~/.cli-workbench-backup/<timestamp>/RESTORE` (one command per file), or delete what you no longer want. `chezmoi unmanage <target>` stops managing one file.

## Troubleshooting

- Debian/Ubuntu: `compinit: initialization aborted` or "insecure directories" at shell start comes from the system's `/etc/zsh/zshrc`, which runs its own `compinit` before yours when `/usr/share/zsh` has loose permissions. The zshrc here already runs `compinit`, so put `skip_global_compinit=1` in `~/.zshenv` (or fix the permissions, see `compaudit`).
- `chezmoi: ... has changed since chezmoi last wrote it`: you edited the deployed file. Run `chezmoi diff`, then `chezmoi re-add` (keep your edit) or `chezmoi apply --force` (take the repository's; your edit goes to the backup first).
- tmux config problems: `tmux -L test -f ~/.tmux.conf new-session -d` loads it on a private socket; `tmux -L test show-messages` prints errors.
- More in [`docs/architecture.md`](docs/architecture.md).

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). For security problems, see [SECURITY.md](SECURITY.md) instead of opening a public issue. Changes between versions are in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
