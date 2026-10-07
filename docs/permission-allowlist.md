# Permission allow-list proposal

A proposal, **not applied**. Nothing in this repository changes `~/.claude/settings.json`; the owner of the machine reads this page, picks rules, and adds them.

## Why

Auto mode decides each permission prompt with a classifier that runs on a server. When that service is down, every command that is not already allowed waits for a human, and work stops. Rules in `permissions.allow` are decided on the machine, so they keep working. The most frequent commands an agent runs are read-only; allowing exactly those removes most prompts without removing any safety.

## How the list was made

The list is ranked by how often a command ran in the agent's own transcripts (`~/.claude/projects/*/*.jsonl`, 43 transcript files, 4687 Bash calls). Each call was split at `&&`, `||`, `;`, `|` and newlines, and each part was counted once under its program and subcommand, so a count is "how often this command ran", not "how many calls contained it". Heredoc bodies were cut off. A call that contained a token-like string (a key prefix, a long random string, `Bearer`, or the words token, secret, password, credential, key file names) was dropped before counting (233 calls), and no command text appears on this page. MCP tools were counted too: the most frequent read-only one ran about 20 times, which is too rare to justify a rule; add one case by case (`mcp__<server>__<tool>`).

The counts are a snapshot from one machine on 2026-10-07. Re-run the scan before you rely on them.

## Rules in two tiers

A rule `Bash(git status *)` allows `git status` followed by anything. A rule without `*` allows exactly that command. Commands like `ls`, `cat` and `git status` may already be allowed by Claude Code's built-in read-only set in your version; repeating them is harmless and keeps the list complete if that set changes.

### Tier 1: nothing in the arguments can write, send or run something

Add these first.

| # | Rule | Ran |
|---|---|---|
| 1 | `Bash(cut *)` | 1090 |
| 2 | `Bash(ls *)` | 824 |
| 3 | `Bash(git status *)` | 383 |
| 4 | `Bash(wc *)` | 303 |
| 5 | `Bash(sleep *)` | 189 |
| 6 | `Bash(gh pr view *)` | 113 |
| 7 | `Bash(gh run list *)` | 103 |
| 8 | `Bash(git ls-files *)` | 79 |
| 9 | `Bash(gh run view *)` | 70 |
| 10 | `Bash(tr *)` | 59 |
| 11 | `Bash(du *)` | 54 |
| 12 | `Bash(git branch --show-current)` | 50 |
| 13 | `Bash(gh pr checks *)` | 50 |
| 14 | `Bash(gh pr list *)` | 45 |
| 15 | `Bash(claude plugin validate *)` | 43 |
| 16 | `Bash(git rev-parse *)` | 39 |
| 17 | `Bash(git worktree list *)` | 37 |
| 18 | `Bash(date *)` | 34 |
| 19 | `Bash(git check-ignore *)` | 31 |
| 20 | `Bash(diff *)` | 29 |
| 21 | `Bash(git ls-tree *)` | 27 |
| 22 | `Bash(chezmoi diff *)` | 25 |
| 23 | `Bash(chezmoi verify *)` | 24 |
| 24 | `Bash(which *)` | 24 |
| 25 | `Bash(git rev-list *)` | 23 |
| 26 | `Bash(gh repo view *)` | 21 |
| 27 | `Bash(stat *)` | 21 |
| 28 | `Bash(cmp *)` | 18 |
| 29 | `Bash(git stash list *)` | 16 |
| 30 | `Bash(git branch -vv)` | 15 |
| 31 | `Bash(shellcheck *)` | 13 |
| 32 | `Bash(chezmoi managed *)` | 12 |
| 33 | `Bash(chezmoi source-path *)` | 10 |
| 34 | `Bash(git merge-base *)` | 9 |
| 35 | `Bash(git branch -r)` | 9 |
| 36 | `Bash(git branch -a)` | 8 |
| 37 | `Bash(git branch --list *)` | 8 |
| 38 | `Bash(tmux list-keys *)` | 8 |
| 39 | `Bash(chezmoi status *)` | 7 |
| 40 | `Bash(claude plugin list *)` | 7 |
| 41 | `Bash(gh pr diff *)` | 4 |
| 42 | `Bash(tmux list-panes *)` | 4 |
| 43 | `Bash(git tag -l *)` | 3 |
| 44 | `Bash(gh workflow list *)` | 3 |
| 45 | `Bash(gh issue list *)` | 2 |
| 46 | `Bash(gh issue view *)` | 2 |
| 47 | `Bash(tmux list-windows *)` | 2 |

### Tier 2: read-only, but one argument can write, run a program or reveal a secret

Decide each one yourself. The risk is the argument named in the last column, which an agent would have to choose on purpose.

| # | Rule | Ran | What the worst argument does |
|---|---|---|---|
| 1 | `Bash(head *)` | 2798 | reads any file |
| 2 | `Bash(rg *)` | 1837 | reads any file; `--pre CMD` runs a program on each file |
| 3 | `Bash(tail *)` | 1286 | reads any file |
| 4 | `Bash(grep *)` | 1245 | reads any file |
| 5 | `Bash(cat *)` | 736 | reads any file |
| 6 | `Bash(git log *)` | 433 | `--output=FILE` writes a file |
| 7 | `Bash(jq *)` | 252 | `env` and `$ENV` print the environment, secrets included |
| 8 | `Bash(sort *)` | 230 | `-o FILE` writes a file |
| 9 | `Bash(git show *)` | 204 | `--output=FILE` writes a file |
| 10 | `Bash(git diff *)` | 183 | `--output=FILE` writes a file |
| 11 | `Bash(git grep *)` | 127 | `-O CMD` runs a program as pager |
| 12 | `Bash(uniq *)` | 71 | a second file operand is written to |
| 13 | `Bash(lsof *)` | 43 | lists the files other processes hold open |

Two things make Tier 2 safer than it looks. Claude Code's sandbox, when it is on, has a read-deny list that covers `.env` files, `~/.ssh` and secret-named files for commands run inside the sandbox. And you can pair the allow rules with deny rules, which win over allow rules: `Read(**/.env*)`, `Read(~/.ssh/**)`, `Read(~/.config/zsh/secrets.zsh)`. Deny rules for the Read tool are matched best-effort against Bash commands, so treat them as a seat belt, not a lock.

## Left out on purpose

| Commands | Ran | Why they stay behind a prompt |
|---|---|---|
| `gh api *` | 59 | a GET by default, but `-X POST`, `-f` and `-F` send data |
| `sed *` | 1371 | `-i` edits files in place, a `w` command writes |
| `awk *`, `perl *`, `python3 *`, `node *`, `bash *`, `sh *` | 1404 | run arbitrary code |
| `find *`, `xargs *`, `timeout *` | 171 | `-exec`, `-delete` and the commands they start |
| `curl *` | 92 | can send data to any host |
| `git add`, `commit`, `push`, `fetch`, `checkout`, `switch`, `stash`, `worktree add/remove`, `branch -D` | 1280 | change the repository or the remote |
| `gh pr merge/create/close/edit/ready`, `gh run rerun/cancel`, `gh workflow run` | 71 | change GitHub |
| `rm`, `mv`, `cp`, `mkdir`, `touch`, `chmod`, `ln`, `kill`, `pkill` | 676 | change files or processes |
| `cargo`, `npm`, `pnpm` | 251 | run the project's own code (tests, build scripts) |
| `ps *`, `pgrep *` | 57 | command lines can contain tokens |
| `launchctl print *` | 29 | prints a service's environment |
| `git config *`, `git remote -v`, `git remote get-url`, `gh auth status`, `claude mcp get` | 89 | can print remote URLs, tokens or server environments |
| `sqlite3 *`, `psql *`, `plutil *` | 56 | can write; `plutil -convert` rewrites files |

## How to apply it

1. Read the two tables and decide.
2. Add the chosen rules to `permissions.allow` in `~/.claude/settings.json` (this repository does not manage that file, on purpose; see the README). Example:

   ```json
   {
     "permissions": {
       "allow": [
         "Bash(git status *)",
         "Bash(git rev-parse *)"
       ]
     }
   }
   ```

3. Check one rule in a session: run a command it covers and see that no prompt appears. If a bare command such as `ls` still asks, add the bare form (`Bash(ls)`) next to the `*` form.
4. Repeat the scan in a month and move rules that never ran out of the list.
