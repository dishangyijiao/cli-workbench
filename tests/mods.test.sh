#!/usr/bin/env bash
# Claude Code mods: a local marketplace under home/dot_claude/workbench-mods, deployed to ~/.claude/workbench-mods.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v chezmoi >/dev/null; then echo "chezmoi not installed; skipped"; exit 0; fi
if ! command -v jq >/dev/null; then echo "jq not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d "${TMPDIR:-/tmp}/wb-mods.XXXXXX")" && pwd)
trap t_cleanup EXIT

H=$T_DIR/h; mkdir -p "$H"; t_render "$H"
M=$H/.claude/workbench-mods
MARKET=$M/.claude-plugin/marketplace.json

echo "the marketplace is deployed and names every mod"
assert "marketplace.json is deployed" test -s "$MARKET"
assert "marketplace.json is valid JSON" jq -e . "$MARKET"
assert_eq "marketplace name" "cli-workbench" "$(jq -r .name "$MARKET" 2>/dev/null)"
assert_eq "the mods listed" "chezmoi-guard reply-polish" "$(jq -r '.plugins[].name' "$MARKET" 2>/dev/null | sort | tr '\n' ' ' | sed 's/ $//')"

for name in chezmoi-guard reply-polish; do
  echo "$name"
  source=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .source' "$MARKET" 2>/dev/null)
  dir=$M/${source#./}
  assert_eq "$name: source is a path inside the marketplace" "./$name" "$source"
  assert "$name: plugin.json is valid JSON" jq -e . "$dir/.claude-plugin/plugin.json"
  assert_eq "$name: plugin.json name matches its folder" "$name" "$(jq -r .name "$dir/.claude-plugin/plugin.json" 2>/dev/null)"
  refute "$name: the name does not look like one of Anthropic's own" jq -e '.name | startswith("claude-")' "$dir/.claude-plugin/plugin.json"
  assert "$name: hooks.json is valid JSON" jq -e . "$dir/hooks/hooks.json"
  module=$(jq -r '.modules[0]' "$dir/hooks/hooks.json" 2>/dev/null)
  assert "$name: the hooks module exists" test -f "$dir/hooks/$module"
  assert "$name: it ships tests" test -n "$(find "$dir" -name '*.test.ts' | head -1)"
  refute "$name: nothing imports from outside its folder" grep -rEq "from '(\.\./){2}" "$dir/hooks"
  refute "$name: no generated types are tracked" test -e "$dir/.claude-plugin/types"
done

echo "with Claude Code installed: validate and run each mod's own tests"
if command -v claude >/dev/null && claude plugin test --help >/dev/null 2>&1; then
  assert "the marketplace validates" claude plugin validate "$M"
  for name in chezmoi-guard reply-polish; do
    assert "$name validates" claude plugin validate "$M/$name"
    assert "$name passes its tests" claude plugin test "$M/$name"
  done
else
  echo "  skip claude plugin validate/test (Claude Code with mods, v2.1.287 or later, not installed)"
fi

t_done
