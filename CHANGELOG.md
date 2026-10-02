# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). Before 1.0.0, minor versions may contain breaking changes.

## [Unreleased]

### Changed

- **Breaking:** deployment moved from the home-grown symlink tooling to [chezmoi](https://www.chezmoi.io). The repository is now a chezmoi source tree under `home/` (`.chezmoiroot`); `config/` is gone. Files are copied, not symlinked, so an edit takes effect after `chezmoi apply`, and chezmoi itself keeps no backup of files it replaces, so `scripts/backup-before-apply` (a `hooks.apply.pre` hook written by `chezmoi init`) does it. To migrate from the symlink setup, remove the old links, run `chezmoi init --source <clone>`, and `chezmoi apply` (see the README).
- The portable Git settings are now deployed to `~/.config/git/config`, which Git reads by itself; the `include.path` line in `~/.gitconfig` is no longer needed.
- `zshrc` loads `path.zsh` from `~/.config/zsh/` instead of from next to itself; `~/.config/zsh` is created with mode 700.
- CI installs chezmoi (macOS: Homebrew; Ubuntu: a pinned, checksum-verified release).
- `privacy-scan` no longer mistakes `home/dot_*` for a personal `/home/<name>` path.
- The pre-commit hook and CI (Ubuntu) run `scripts/lint-shell`, which runs shellcheck at warning level over every bash/sh script; five existing warnings in `tests/` are fixed.

### Added

- A pre-push hook and a `privacy-scan --commits` mode: before every push, the author, the committer and the message of each commit the push would add are scanned for token formats, private keys and your private words from the deny list (`~/.config/cli-workbench/deny.txt`) — metadata that file scans never see. The e-mail rule does not apply there (a commit's own address is the author's choice); a missing deny list warns, since commit metadata is then only checked against the token formats.
- One instruction text for every agent CLI: `home/.chezmoitemplates/agent-instructions.md` is rendered to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` and `~/.gemini/GEMINI.md`, with `~/.config/cli-workbench/agent-instructions.local.md` (untracked) appended when present. Existing files are backed up before they are replaced. A test keeps agent credentials, histories, sessions and settings files out of `home/`.
- Workspace switcher: an AI CLI agent pane (editor left, agent over a shell on the right). The first installed of `claude codex gemini grok` is started in the project directory; `WORKSPACE_SWITCH_AGENT` picks one (with arguments) or `none`, `WORKSPACE_SWITCH_AGENTS` sets the candidates. Without an installed agent the layout is unchanged.
- `privacy-scan` recognises xAI (Grok) keys; tests also cover Anthropic and Google (Gemini) keys.
- `scripts/backup-before-apply` and `home/.chezmoi.toml.tmpl`: before every `chezmoi apply` (including `apply <one file>`), files that would be replaced, including ones edited since chezmoi wrote them, are copied to `~/.cli-workbench-backup/<timestamp>/` (mode 700, symlinks preserved, `RESTORE` note). Nothing is created when nothing changes, `--dry-run` has no side effects, and a failed backup refuses the apply.

### Removed

- The Neovim `avante.nvim` AI plugin and its six plugin dependencies: it called a model API directly (a hard-coded outdated model id, and an API key stored in plain text), a second path next to the CLI agents. Run `:Lazy clean` to remove the leftovers.
- `scripts/link`, `scripts/check`, `scripts/doctor`, `scripts/bootstrap`, `scripts/zsh-snapshot`, `scripts/lib.sh`, `links.txt` and their tests; chezmoi's `diff`, `verify` and `doctor` replace them. The `--deep` startup check of the old `doctor` has no replacement; the test suite still starts zsh, tmux and nvim in throwaway HOMEs.

### Fixed

- `zshrc`: starship is no longer started under `TERM=dumb` or with `TERM` unset (test harnesses, some editor shells). It cannot render there and printed an error at every prompt; the built-in prompt is used instead, so a fresh interactive zsh starts silently again. The smoke test pins the choice for both TERMs.
- `privacy-scan`: a secret-looking assignment is now caught when its value contains symbols such as `&` or `!` (the scan stopped at the first one and reported nothing), and a placeholder word such as "example" in a trailing comment no longer hides it: placeholders are judged on the assignment, not on the whole line. Private keys and token formats are also checked in the scanner's own fixture files, which were skipped entirely before.
- `workspace-switch.sh`: when two directories with the same name (`~/a/foo`, `~/b/foo`) were opened at the same moment, the loser was silently switched to the winner's session, i.e. into the wrong project. It now checks which directory owns the session it lost the race for, and picks another name if it is not its own.
- `zshrc`: the completion dump was always reused (`compinit -C`), so completions of a tool installed later (`brew install ...`) never appeared until the dump was deleted by hand. It is now reused only while it is less than a day old; after that `compinit` checks fpath again and rebuilds it if something new is there. A fresh dump still starts fast.
- **Security:** `tmux.conf` pasted the pane's directory into shell commands (`prefix + N`, and the branch shown in the pane border, which refreshes by itself). tmux expands `#{pane_current_path}` before the shell runs, so a directory named like `$(...)`, for example a subdirectory of a cloned repository, ran that command as you. Both now pass only the pane id; `branch.sh` accepts a pane id and looks the directory up itself (it still accepts a directory). `tests/tmux-conf.test.sh` runs `prefix + N` in such a directory and also fails if a directory, title or name format is put into a shell command again.
- Neovim `<leader>gm` (open the GitLab merge request of the current line): a project name with a dot (`group/my.project`) was cut at the dot, so the wrong page opened; the repository (and so its remote) was taken from the directory Neovim was started in instead of the one that holds the file; and the URL went through a shell inside single quotes, so a remote containing a quote could run a command. The URL is now built in `lua/git/gitlab.lua`, which accepts only what GitLab allows in a path, drops credentials from an `https://user:token@` remote, and refuses anything else; the browser is opened with `vim.ui.open`, with no shell, and an error from it is shown. Supported remotes are as before (`git@host:` and `https://`; host names may contain `_`). `tests/nvim-gitlab.test.sh` covers the URL part (it needs `nvim`).
- `statusline.sh`: the git cache lived in a predictable directory in `/tmp` and an entry was printed as it was found. On a shared Linux machine another user could create that directory first and plant an entry containing terminal escape sequences. The cache now goes under `$XDG_RUNTIME_DIR` when it is set, is used only if its directory is ours and not a symlink (checked again after the directory is created, before anything is written), and the directory name and the branch are stripped of control characters and the two counters must be plain numbers before they are printed.
- Neovim `init.lua` loaded `lsp/` and `git/` with a bare `pcall(require, ...)`, so one error in them (for example an lspconfig API that was renamed after `:Lazy update`) silently turned off completion and every language server. The error is now shown by the new `lua/safe_require.lua`; a module that is not installed yet, which is normal on the first start, is only a warning.

## [0.0.1] - 2026-10-01

First public release.

### Added

- `scripts/link`: symlink components listed in `links.txt`; dry run by default, `--apply` to change, `--adopt` for real directories and foreign links, backups with a `RESTORE` note in `~/.cli-workbench-backup/<timestamp>/`, all-or-nothing preflight across selected components.
- `scripts/check`, `scripts/doctor` (`--deep` starts zsh, tmux and nvim), `scripts/bootstrap`, `scripts/zsh-snapshot`.
- Default configs: zsh (shared history, optional `starship`, `zoxide`, `fzf`, `zsh-syntax-highlighting`, colored `ls` and `grep`), tmux (prefix `Ctrl-a`, workspace switcher), Ghostty, portable Git settings, Claude Code status line, optional Neovim setup with pinned plugins.
- `scripts/privacy-scan` with a pre-commit hook and a CI gate.
- Test suite (`tests/run.sh`) including an end-to-end run of the README quick start; GitHub Actions on macOS and Ubuntu, plus the macOS system bash 3.2.
- English and Simplified Chinese READMEs, `SECURITY.md`, `CONTRIBUTING.md`, issue and pull request templates.

[Unreleased]: https://github.com/dishangyijiao/cli-workbench/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/dishangyijiao/cli-workbench/releases/tag/v0.0.1
