#!/usr/bin/env bash
# Exercise the partial Codex configuration merge in isolated homes.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v chezmoi >/dev/null; then echo "chezmoi not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT
H=$T_DIR/home
mkdir -p "$H/.codex"
apply_config() {
  HOME="$H" chezmoi apply --source "$WB_SRC" --destination "$H" --no-tty \
    --cache "$H/.cache" --persistent-state "$H/.state" "$H/.codex/config.toml"
}
assert "fresh machine receives portable preferences" apply_config
assert "new config has both rate limits and completion bell" bash -c '
  chezmoi execute-template "{{ include \"$1\" | fromToml | toJson }}" | jq -e '\''
    .tui.status_line == ["model-with-reasoning", "current-dir", "thread-name", "five-hour-limit", "weekly-limit"] and
    .tui.notifications == ["agent-turn-complete"] and
    .tui.notification_method == "bel" and .tui.notification_condition == "always"
  '\''
' _ "$H/.codex/config.toml"
cat > "$H/.codex/config.toml" <<'TOML'
# Existing local settings
model = "local-model"
notify = ["/opt/local-notifier", "turn-ended"]
[projects."/work/example"]
trust_level = "trusted"
[tui]
status_line = ["model"]
notifications = false
notification_method = "auto"
theme = "local-theme"
[tui.model_availability_nux]
example = 4
TOML
assert "existing configuration merges successfully" apply_config
assert "unmanaged nested settings and local paths survive" bash -c '
  chezmoi execute-template "{{ include \"$1\" | fromToml | toJson }}" | jq -e '\''
    .model == "local-model" and .notify == ["/opt/local-notifier", "turn-ended"] and
    .projects["/work/example"].trust_level == "trusted" and
    .tui.theme == "local-theme" and .tui.model_availability_nux.example == 4 and
    .tui.notification_method == "bel"
  '\''
' _ "$H/.codex/config.toml"
printf '\n# Keep comments when preferences already match.\n' >> "$H/.codex/config.toml"
cp "$H/.codex/config.toml" "$T_DIR/expected"
assert "second apply succeeds" apply_config
assert "matching configuration remains byte-for-byte unchanged" cmp -s "$T_DIR/expected" "$H/.codex/config.toml"
printf '[tui\n' > "$H/.codex/config.toml"
cp "$H/.codex/config.toml" "$T_DIR/invalid"
refute "invalid TOML aborts the merge" apply_config
assert "invalid input is not overwritten" cmp -s "$T_DIR/invalid" "$H/.codex/config.toml"
t_done
