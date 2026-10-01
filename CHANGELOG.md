# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). Before 1.0.0, minor versions may contain breaking changes.

## [Unreleased]

### Changed

- **Breaking:** deployment moved from the home-grown symlink tooling to [chezmoi](https://www.chezmoi.io). The repository is now a chezmoi source tree under `home/` (`.chezmoiroot`); `config/` is gone. Files are copied, not symlinked, so an edit takes effect after `chezmoi apply`, and chezmoi does not back up files it replaces: run `chezmoi diff` first. To migrate from the symlink setup, remove the old links, point `sourceDir` at your clone, and `chezmoi apply` (see the README).
- The portable Git settings are now deployed to `~/.config/git/config`, which Git reads by itself; the `include.path` line in `~/.gitconfig` is no longer needed.
- `zshrc` loads `path.zsh` from `~/.config/zsh/` instead of from next to itself; `~/.config/zsh` is created with mode 700.
- CI installs chezmoi (macOS: Homebrew; Ubuntu: a pinned, checksum-verified release).
- `privacy-scan` no longer mistakes `home/dot_*` for a personal `/home/<name>` path.

### Removed

- `scripts/link`, `scripts/check`, `scripts/doctor`, `scripts/bootstrap`, `scripts/zsh-snapshot`, `scripts/lib.sh`, `links.txt` and their tests; chezmoi's `diff`, `verify` and `doctor` replace them. The `--deep` startup check of the old `doctor` has no replacement; the test suite still starts zsh, tmux and nvim in throwaway HOMEs.

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
