# Contributing

Issues and pull requests are welcome. For security problems, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Before you open a pull request

1. Enable the git hooks once per clone, so `scripts/privacy-scan` and `scripts/lint-shell` run before every commit, `scripts/tdd-gate` checks every commit message, and `scripts/privacy-scan` runs before every push:

   ```sh
   git config core.hooksPath .githooks
   ```

2. Keep scripts bash 3.2 compatible (the macOS system bash). CI runs the suite with it.
3. Develop test-first (see [Test-driven development](#test-driven-development)) and run the whole suite:

   ```sh
   tests/run.sh
   ```

4. Lint the shell scripts (needs `shellcheck`: `brew install shellcheck`). It reports warnings and errors; the pre-commit hook and CI run it too:

   ```sh
   scripts/lint-shell
   ```

5. When user-visible behaviour changes, update both `README.md` and `README.zh-CN.md`, and add a line under `Unreleased` in [CHANGELOG.md](CHANGELOG.md). If you cannot write the Chinese part, say so in the pull request and a maintainer will add it.

## Test-driven development

Every behaviour change follows red, green, refactor:

1. **Red.** Write the test first (a new `tests/*.test.sh`, or a new case in an existing one) and run it. It must fail, and for the reason you expect, not because of a typo.
2. **Green.** Write the least code that makes it pass.
3. **Refactor.** Clean up with the suite green.

A bug fix starts with a test that reproduces the bug. Commit the test together with the change (the commit-msg hook and review both check this); one commit per red-green cycle keeps `git bisect` useful.

`scripts/tdd-gate` enforces the part a machine can check: a `feat`, `fix`, `refactor` or `perf` commit (also `feat!:` and the like) that changes `home/`, `scripts/` or `.githooks/` must add or change a `tests/*.test.sh` in the same commit. Deleting a test does not count. It runs twice:

- locally, as the `commit-msg` hook. It judges an `--amend` by the whole amended commit, and lets a merge commit through.
- in CI, over every commit of a pull request (`scripts/tdd-gate --range <base>..<head>`), because `git commit --no-verify` skips the hook. A pull request whose commits fail cannot go green; fix them with `git rebase -i`, not with another commit.

A change with no behaviour, such as a comment, may say so with a line `tdd: skip - <reason>` in the commit message; CI prints every use of it. The gate cannot see whether the test came first, whether it is meaningful, or whether it fails without the change, so say in the pull request how you saw it fail, and the reviewer checks.

## Language

Code, comments, commit messages and every file except `README.zh-CN.md` are in English.

## No personal data

Do not commit personal paths, names, e-mail addresses or credentials. `scripts/privacy-scan` checks for private keys, token formats, secret-looking assignments, `/Users/<name>` and `/home/<name>` paths, e-mail addresses, `.env`/`*.pem`/`*.key` files, and your own words from `~/.config/cli-workbench/deny.txt` (one word per line, kept outside the repo). The pre-commit and pre-push hooks and CI all run it. A deliberate exception: put `wb-scan: allow` on that line.

To keep your e-mail address out of commit metadata, commit with your GitHub noreply address (Settings > Emails on GitHub). File scans never see commit metadata, so the pre-push hook scans the author, the committer and the message of every commit a push would add; put your private address (and other private words) in `~/.config/cli-workbench/deny.txt` and the hook refuses the push.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org): a short imperative subject with an optional scope, for example `feat(tmux): ...`, `fix(zsh): ...`, `docs: ...`.
