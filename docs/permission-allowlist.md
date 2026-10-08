# Permission allow-list proposal

A proposal, **not applied**. Nothing in this repository changes `~/.claude/settings.json`; the owner of the machine reads this page, picks rules, and adds them.

## Why

Auto mode decides each permission prompt with a classifier that runs on a server. When that service is down, every command that is not already allowed waits for a human, and work stops. Rules in `permissions.allow` are decided on the machine, so they keep working. The most frequent commands an agent runs are read-only; allowing exactly those removes most prompts.

## How the list was made

The list is ranked by how often a command ran in the agent's own transcripts (`~/.claude/projects/*/*.jsonl`, 43 transcript files, 4687 Bash calls). Each call was split at `&&`, `||`, `;`, `|` and newlines, and each part was counted once under its program and subcommand, so a count is "how often this command ran", not "how many calls contained it". Heredoc bodies were cut off. A call that contained a token-like string (a key prefix, a long random string, `Bearer`, or the words token, secret, password, credential, key file names) was dropped before counting (233 calls), and no command text appears on this page. MCP tools were counted too: the most frequent read-only one ran about 20 times, which is too rare to justify a rule; add one case by case (`mcp__<server>__<tool>`).

The counts are a snapshot from one machine on 2026-10-07. Re-run the scan before you rely on them.

## How a rule matches

`Bash(git status *)` allows `git status` followed by anything. A rule without `*` allows exactly that command and nothing else. A rule with `*` therefore allows every argument, and the review that matters is what the worst argument does. Each rule below was checked for that: Tier 1 rules have no argument that writes a file, runs a program, chains another command or reads the contents of a file. Tier 1 is a statement about arguments, not about configuration: it assumes that the tool itself, its configuration and the repository you are in are yours. Where a program has such an argument (`git stash list --output=FILE`, `tmux list-panes \; run-shell CMD`), the rule is exact, without `*`, or the program is not on the list. Commands that render templates (`chezmoi`) or can launch a browser (`gh ... --web`) are in Tier 2, because template functions such as `output` run programs and `--web` starts another application. Commands such as `ls` and `git status` may already be allowed by Claude Code's built-in read-only set in your version; repeating them is harmless.

One more limit: a rule matches how the command starts. Repository settings can still change what a command does (a `git` alias, `core.fsmonitor`, `core.pager` in a repository you did not write), so do not allow these commands inside a repository you do not trust.

## Tier 1: no argument writes, runs a program, chains a command or prints file contents

Add these first. `ls`, `wc`, `du`, `stat` and `which` show names, sizes and counts, not content. The `git` rules show repository metadata.

| # | Rule | Ran |
|---|---|---|
| 1 | `Bash(ls *)` | 824 |
| 2 | `Bash(git status *)` | 383 |
| 3 | `Bash(wc *)` | 303 |
| 4 | `Bash(sleep *)` | 189 |
| 5 | `Bash(git ls-files *)` | 79 |
| 6 | `Bash(tr *)` | 59 |
| 7 | `Bash(du *)` | 54 |
| 8 | `Bash(git branch --show-current)` | 50 |
| 9 | `Bash(git rev-parse *)` | 39 |
| 10 | `Bash(git worktree list *)` | 37 |
| 11 | `Bash(git check-ignore *)` | 31 |
| 12 | `Bash(git ls-tree *)` | 27 |
| 13 | `Bash(which *)` | 24 |
| 14 | `Bash(git rev-list *)` | 23 |
| 15 | `Bash(stat *)` | 21 |
| 16 | `Bash(git stash list)` | 16 |
| 17 | `Bash(git branch -vv)` | 15 |
| 18 | `Bash(git merge-base *)` | 9 |
| 19 | `Bash(git branch -r)` | 9 |
| 20 | `Bash(git branch -a)` | 8 |
| 21 | `Bash(tmux list-keys)` | 8 |
| 22 | `Bash(tmux list-panes -a)` | 4 |
| 23 | `Bash(tmux list-windows)` | 2 |

## Tier 2: read-only, but an argument can write, run a program or print a secret

Decide each one yourself, and read the next section first. The last column is what the worst argument does; an agent would have to choose it on purpose, but a prompt injected into a file or a web page could ask it to.

| # | Rule | Ran | What the worst argument does |
|---|---|---|---|
| 1 | `Bash(head *)` | 2798 | prints any file it is given |
| 2 | `Bash(rg *)` | 1837 | `--pre CMD` runs a program on every file; also reads any file |
| 3 | `Bash(tail *)` | 1286 | prints any file it is given |
| 4 | `Bash(grep *)` | 1245 | prints matching lines of any file, recursively with `-r` |
| 5 | `Bash(cut *)` | 1090 | prints any file it is given |
| 6 | `Bash(cat *)` | 736 | prints any file it is given |
| 7 | `Bash(git log *)` | 433 | repository-configured diff and textconv drivers run programs; `--output=FILE` writes a file; shows committed content |
| 8 | `Bash(jq *)` | 252 | reads any file; `env` and `$ENV` print the environment, secrets included |
| 9 | `Bash(sort *)` | 230 | `-o FILE` writes a file; reads any file |
| 10 | `Bash(git show *)` | 204 | repository-configured diff and textconv drivers run programs; `--output=FILE` writes a file; shows committed content |
| 11 | `Bash(git diff *)` | 183 | repository-configured diff and textconv drivers run programs; `--output=FILE` writes a file; shows file content |
| 12 | `Bash(git grep *)` | 127 | `-O CMD` runs a program as pager; reads any tracked file |
| 13 | `Bash(gh pr view *)` | 113 | `--web` launches a browser; `gh` reads your GitHub login |
| 14 | `Bash(gh run list *)` | 103 | `--web` launches a browser; `gh` reads your GitHub login |
| 15 | `Bash(uniq *)` | 71 | a second file operand is written to |
| 16 | `Bash(gh run view *)` | 70 | `--web` launches a browser; `gh` reads your GitHub login |
| 17 | `Bash(gh pr checks *)` | 50 | `--web` launches a browser; `gh` reads your GitHub login |
| 18 | `Bash(gh pr list *)` | 45 | `--web` launches a browser; `gh` reads your GitHub login |
| 19 | `Bash(lsof *)` | 43 | lists what other processes hold open, with their paths |
| 20 | `Bash(claude plugin validate *)` | 43 | loads and parses the folder it is given |
| 21 | `Bash(diff *)` | 29 | prints the content of any two files |
| 22 | `Bash(chezmoi diff)` | 25 | chezmoi renders templates, and template functions such as `output` run programs from the source repository |
| 23 | `Bash(chezmoi verify)` | 24 | chezmoi renders templates, and template functions such as `output` run programs from the source repository |
| 24 | `Bash(gh repo view *)` | 21 | `--web` launches a browser; `gh` reads your GitHub login |
| 25 | `Bash(cmp *)` | 18 | `-l` prints the differing bytes of any two files |
| 26 | `Bash(shellcheck *)` | 13 | prints source lines of any file it is given |
| 27 | `Bash(chezmoi managed)` | 12 | chezmoi renders templates, and template functions such as `output` run programs from the source repository |
| 28 | `Bash(chezmoi source-path)` | 10 | chezmoi renders templates, and template functions such as `output` run programs from the source repository |
| 29 | `Bash(chezmoi status)` | 7 | chezmoi renders templates, and template functions such as `output` run programs from the source repository |
| 30 | `Bash(gh pr diff *)` | 4 | `--web` launches a browser; `gh` reads your GitHub login |
| 31 | `Bash(gh workflow list *)` | 3 | `--web` launches a browser; `gh` reads your GitHub login |
| 32 | `Bash(gh issue list *)` | 2 | `--web` launches a browser; `gh` reads your GitHub login |
| 33 | `Bash(gh issue view *)` | 2 | `--web` launches a browser; `gh` reads your GitHub login |

### Secrets: no default protection

Every Tier 2 rule that prints a file can print any file you can read: `~/.ssh`, `.env` files, `~/.config/zsh/secrets.zsh`, shell history. Claude Code's sandbox does not stop that by default: it lets commands read most of the file system, credentials included, and a `Read(...)` deny rule applies to the Read tool, not reliably to what `cat`, `rg` or `grep -r` do (see [the sandbox documentation](https://code.claude.com/docs/en/sandboxing#what-the-sandbox-restricts) and [permissions](https://code.claude.com/docs/en/permissions#read-and-edit)). So:

1. Do not treat arbitrary file reads as safe. Allow a Tier 2 rule only if you accept that an agent can print any file you can read.
2. To close the gap, set `sandbox.filesystem.denyRead` for the paths that hold secrets (your SSH directory, `.env` files, the zsh secrets file, credential stores), and **test it**: run `cat` on a decoy file under a denied path from inside a Claude Code session and check that it is refused. Do not rely on it until you have seen it refuse.
3. A rule cannot allow `rg` without `rg --pre`, or `git grep` without `git grep -O`. Allowing those rules therefore also allows running a program that the agent names. If that is not acceptable, leave `rg *`, `git grep *`, `sort *`, `uniq *` and the `git log/show/diff` rules out; the agent then asks for each use, which is the safe default.

## Left out on purpose

| Commands | Ran | Why they stay behind a prompt |
|---|---|---|
| `gh api *` | 59 | a GET by default, but `-X POST`, `-f` and `-F` send data |
| `sed *` | 1371 | `-i` edits files in place, a `w` command writes |
| `awk *`, `perl *`, `python3 *`, `node *`, `bash *`, `sh *` | 1404 | run arbitrary code |
| `find *`, `xargs *`, `timeout *`, `env *` | 175 | `-exec`, `-delete` and the commands they start |
| `curl *` | 92 | can send data to any host |
| `tmux *` with arguments of any kind | 2 | `\;` chains a second tmux command, and `run-shell` runs a program |
| `chezmoi apply *` | 11 | writes the deployed files |
| `git add`, `commit`, `push`, `fetch`, `checkout`, `switch`, `stash` (other than `list`), `worktree add/remove`, `branch -D` | 1280 | change the repository or the remote; `git stash list --output=FILE` even writes a file, which is why `git stash list` has no `*` |
| `gh pr merge/create/close/edit/ready`, `gh run rerun/cancel`, `gh workflow run` | 71 | change GitHub |
| `rm`, `mv`, `cp`, `mkdir`, `touch`, `chmod`, `ln`, `kill`, `pkill` | 676 | change files or processes |
| `cargo`, `npm`, `pnpm` | 251 | run the project's own code (tests, build scripts) |
| `ps *`, `pgrep *`, `date *` | 91 | command lines can contain tokens; `date -f` and `-s` read or set |
| `launchctl print *` | 29 | prints a service's environment |
| `git config *`, `git remote *`, `gh auth status`, `claude mcp get` | 97 | can print remote URLs, tokens or server environments |
| `sqlite3 *`, `psql *`, `plutil *` | 56 | can write; `plutil -convert` rewrites files |

## How to apply it

1. Read the tables and decide.
2. Add the chosen rules to `permissions.allow` in `~/.claude/settings.json` (this repository does not manage that file, on purpose; see the README). Example:

   ```json
   {
     "permissions": {
       "allow": [
         "Bash(git status *)",
         "Bash(git rev-parse *)",
         "Bash(git branch --show-current)"
       ]
     }
   }
   ```

3. Check one rule in a session: run a command it covers and see that no prompt appears, then run one it must not cover (for example `git status; touch x`) and see that the prompt still appears. If a bare command such as `ls` still asks, add the bare form (`Bash(ls)`) next to the `*` form.
4. Repeat the scan in a month and move rules that never ran out of the list.
