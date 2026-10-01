# Contributing

Issues and pull requests are welcome. For security problems, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Before you open a pull request

1. Enable the git hooks once per clone, so `scripts/privacy-scan` runs before every commit and every push:

   ```sh
   git config core.hooksPath .githooks
   ```

2. Keep scripts bash 3.2 compatible (the macOS system bash). CI runs the suite with it.
3. Add a test for new behaviour under `tests/`, and run the whole suite:

   ```sh
   tests/run.sh
   ```

4. When user-visible behaviour changes, update both `README.md` and `README.zh-CN.md`, and add a line under `Unreleased` in [CHANGELOG.md](CHANGELOG.md). If you cannot write the Chinese part, say so in the pull request and it will be added.

## Language

Code, comments, commit messages and every file except `README.zh-CN.md` are in English.

## No personal data

Do not commit personal paths, names, e-mail addresses or credentials. `scripts/privacy-scan` checks for private keys, token formats, secret-looking assignments, `/Users/<name>` and `/home/<name>` paths, e-mail addresses, `.env`/`*.pem`/`*.key` files, and your own words from `~/.config/cli-workbench/deny.txt` (one word per line, kept outside the repo). The pre-commit and pre-push hooks and CI all run it. A deliberate exception: put `wb-scan: allow` on that line.

To keep your e-mail address out of commit metadata, commit with your GitHub noreply address (GitHub, Settings, Emails). File scans never see commit metadata, so the pre-push hook scans the author, the committer and the message of every commit a push would add; put your private address (and other private words) in `~/.config/cli-workbench/deny.txt` and the hook refuses the push.

## Commit messages

Short imperative subject, optionally with a scope, for example `feat(tmux): ...`, `fix(zsh): ...`, `docs: ...`.
