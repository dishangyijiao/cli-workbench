# Terminal workbench

This machine is a plain-text terminal workbench (cli-workbench), managed with chezmoi. Requires: chezmoi, git, zsh, tmux, `rg` and `jq`.

- **Configuration lives in a Git repository, not in the deployed files.** Find it with `chezmoi source-path`. To change a dotfile, edit its source there, then `chezmoi diff` and `chezmoi apply`, then confirm with `chezmoi verify`. Do not edit `~/.zshrc`, `~/.tmux.conf` or the other deployed copies directly: the next apply would overwrite the edit.
- **Per-machine settings** go in `~/.config/zsh/local.zsh`. **Secrets** live in `~/.config/zsh/secrets.zsh`: never read, print or commit them.
- **Projects** are directories under `~/dev/projects`, each one a tmux session: the editor on the left, you on the top right, a shell below. Stay in the terminal; do not try to open GUI applications.
- **Plain text first.** Prefer `rg`, `jq` and `git` over ad-hoc scripts, and read the files before asking.
- **These instructions are generated** from one source for Claude Code (`~/.claude/CLAUDE.md`), Codex (`~/.codex/AGENTS.md`) and Gemini CLI (`~/.gemini/GEMINI.md`). Change them in `home/.chezmoitemplates/agent-instructions.md` of the repository, or add personal rules to `~/.config/cli-workbench/agent-instructions.local.md` (not tracked; appended below).

## Engineering principles

- **One source, layered.** Each fact lives in one place; copies are generated from it or point to it. Global, project and local layers state only what differs from the layer above.
- **Least privilege.** Give each agent, hook and script only the access its task needs. Reviewers read; one owner writes.
- **Files over conversation.** Decisions, conventions and hand-offs go into files (instructions, docs, tests, commit messages), not only into chat.
- **The simplest thing that works.** Add a tool, layer, agent or file only for a present need; remove what is no longer used, after checking that it is unused.
- **Evidence and a way back.** "Done" and "unused" need evidence: a test, a diff, a log or a command's output, not a guess. Keep a way back before you delete or overwrite.
{{- $local := joinPath .chezmoi.homeDir ".config" "cli-workbench" "agent-instructions.local.md" -}}
{{- if stat $local }}

{{ include $local | trim }}
{{- end }}
