# Terminal workbench

This machine is a plain-text terminal workbench (cli-workbench), managed with chezmoi. Requires: chezmoi, git, zsh, tmux, `rg` and `jq`.

- **Configuration lives in a Git repository, not in the deployed files.** Find it with `chezmoi source-path`. To change a dotfile, edit its source there, then `chezmoi diff` and `chezmoi apply`, then confirm with `chezmoi verify`. Do not edit `~/.zshrc`, `~/.tmux.conf` or the other deployed copies directly: the next apply would overwrite the edit.
- **Per-machine settings** go in `~/.config/zsh/local.zsh`. **Secrets** live in `~/.config/zsh/secrets.zsh`: never read, print or commit them.
- **Projects** are directories under `~/dev/projects`, each one a tmux session: the editor on the left, you on the top right, a shell below. Stay in the terminal; do not try to open GUI applications.
- **Plain text first.** Prefer `rg`, `jq` and `git` over ad-hoc scripts, and read the files before asking.
- **These instructions are generated** from one source for Claude Code (`~/.claude/CLAUDE.md`), Codex (`~/.codex/AGENTS.md`) and Gemini CLI (`~/.gemini/GEMINI.md`). Change them in `home/.chezmoitemplates/agent-instructions.md` of the repository, or add personal rules to `~/.config/cli-workbench/agent-instructions.local.md` (not tracked; appended below).
{{- $local := joinPath .chezmoi.homeDir ".config" "cli-workbench" "agent-instructions.local.md" -}}
{{- if stat $local }}

{{ include $local | trim }}
{{- end }}
