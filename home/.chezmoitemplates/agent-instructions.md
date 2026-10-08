# Terminal workbench

This machine is a plain-text terminal workbench (cli-workbench), managed with chezmoi. Requires: chezmoi, git, zsh, tmux, `rg` and `jq`.

- **Configuration lives in a Git repository, not in the deployed files.** Find it with `chezmoi source-path`. To change a dotfile, edit its source there, then `chezmoi diff` and `chezmoi apply`, then confirm with `chezmoi verify`. Do not edit `~/.zshrc`, `~/.tmux.conf` or the other deployed copies directly: the next apply would overwrite the edit.
- **Per-machine settings** go in `~/.config/zsh/local.zsh`. **Secrets** live in `~/.config/zsh/secrets.zsh`: never read, print or commit them.
- **Projects** are directories under `~/dev/projects`, each one a tmux session: you on top, a shell below. The user reads code in a Neovim popup (`prefix e`, `prefix g`), not in a pane. Stay in the terminal; do not try to open GUI applications.
- **Plain text first.** Prefer `rg`, `jq` and `git` over ad-hoc scripts, and read the files before asking.
- **These instructions are generated** from one source for Claude Code (`~/.claude/CLAUDE.md`), Codex (`~/.codex/AGENTS.md`) and Gemini CLI (`~/.gemini/GEMINI.md`). Change them in `home/.chezmoitemplates/agent-instructions.md` of the repository, or add personal rules to `~/.config/cli-workbench/agent-instructions.local.md` (not tracked; appended below).

## Engineering principles

- **One source, layered.** Each fact lives in one place; copies are generated from it or point to it. Global, project and local layers state only what differs from the layer above.
- **Least privilege.** Give each agent, hook and script only the access its task needs. One agent writes to a working copy at a time; reviewers only read.
- **Files over conversation.** Decisions, conventions and hand-offs go into files (instructions, docs, tests, commit messages), not only into chat.
- **The simplest thing that works.** Add a tool, layer, agent or file only for a present need; remove what is no longer used, after checking that it is unused.
- **Evidence and a way back.** "Done" and "unused" need evidence: a test, a diff, a log or a command's output, not a guess. Keep a way back before you delete or overwrite.

## Working across projects

- **Work where the project lives.** A task for project X belongs in X's own window, which loads X's instructions. If one arrives here (a pasted hand-off, a list of pull requests), say so in the first reply and write a hand-off file for X's window. If the owner asks you to work on X from here, read X's `AGENTS.md` or `CLAUDE.md` before the first change.
- **Pasted state is a claim.** What another session reported (open, merged, green, reviewed) goes stale. Check the live state with `gh` or `git` before you act on it or repeat it.
- **Say what leaves the machine.** Before code from a private repository goes to a hosted service (a reviewer, a scanner), name the service and the repository and get the owner's yes in this conversation.
- **A hand-off is a file.** It holds the goal, the facts with how each was checked, the decisions taken, what is not done and the next step.
{{- $local := joinPath .chezmoi.homeDir ".config" "cli-workbench" "agent-instructions.local.md" -}}
{{- if stat $local }}

{{ include $local | trim }}
{{- end }}
