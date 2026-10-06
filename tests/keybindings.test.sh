#!/usr/bin/env bash
# docs/keybindings.md and docs/keybindings.zh-CN.md list the keys people use most. Every key they name must exist:
# each `prefix X` is bound in the rendered tmux config (loaded into a throwaway tmux server), each `<leader>…` is
# mapped in the Neovim config, and both languages list exactly the same keys.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
EN=$WB_SRC/docs/keybindings.md
ZH=$WB_SRC/docs/keybindings.zh-CN.md
SOCK=wbkeys$$
cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null; t_cleanup; }
trap cleanup EXIT

echo "both languages exist and point to each other"
assert "the English page exists" test -f "$EN"
assert "the Chinese page exists" test -f "$ZH"
assert "English links to Chinese" grep -q '(keybindings.zh-CN.md)' "$EN"
assert "Chinese links to English" grep -q '(keybindings.md)' "$ZH"
assert "README links to it" grep -q 'docs/keybindings.md' "$WB_SRC/README.md"
assert "README.zh-CN links to the Chinese page" grep -q 'docs/keybindings.zh-CN.md' "$WB_SRC/README.zh-CN.md"

# Keys are written in backticks: `prefix e`, `prefix |`, `<leader>ff`.
prefix_keys() { grep -o '`prefix [^`]*`' "$1" | sed 's/^`prefix //; s/`$//; s/^\\|$/|/' | sort -u; }
leader_keys() { grep -o '`<leader>[^`][^`]*`' "$1" | sed 's/^`//; s/`$//' | sort -u; }

echo "both languages list the same keys"
assert "some prefix keys are listed" test -n "$(prefix_keys "$EN" 2>/dev/null)"
assert "some leader keys are listed" test -n "$(leader_keys "$EN" 2>/dev/null)"
assert_eq "the same prefix keys" "$(prefix_keys "$EN" 2>/dev/null | tr '\n' ' ')" "$(prefix_keys "$ZH" 2>/dev/null | tr '\n' ' ')"
assert_eq "the same leader keys" "$(leader_keys "$EN" 2>/dev/null | tr '\n' ' ')" "$(leader_keys "$ZH" 2>/dev/null | tr '\n' ' ')"

echo "every documented prefix key is bound in tmux"
if command -v tmux >/dev/null && command -v chezmoi >/dev/null; then
  H=$T_DIR/home; mkdir -p "$H"; t_render "$H"
  HOME=$H tmux -L "$SOCK" -f "$H/.tmux.conf" new-session -d 2>/dev/null
  bound=$(HOME=$H tmux -L "$SOCK" list-keys -T prefix 2>/dev/null \
    | awk '{for (i = 1; i < NF; i++) if ($i == "prefix") { print $(i + 1); break }}' | sed 's/^\\//')   # -r adds a column
  missing=$(prefix_keys "$EN" 2>/dev/null | while IFS= read -r k; do printf '%s\n' "$bound" | grep -qxF -- "$k" || echo "$k"; done)
  assert_eq "no documented prefix key is unbound" "" "$missing"
else
  echo "  skip  tmux or chezmoi not installed"
fi

echo "every documented <leader> key is mapped in Neovim"
LUA=$WB_SRC/home/dot_config/nvim
missing=$(leader_keys "$EN" 2>/dev/null | while IFS= read -r k; do
  rest=${k#<leader>}
  grep -rqF -e "'$k'" -e "\"$k\"" -e "'<space>$rest'" -e "\"<space>$rest\"" "$LUA" || echo "$k"
done)
assert_eq "no documented leader key is unmapped" "" "$missing"
t_done
