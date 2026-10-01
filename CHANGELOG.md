# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). Before 1.0.0, minor versions may contain breaking changes.

## [Unreleased]

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
