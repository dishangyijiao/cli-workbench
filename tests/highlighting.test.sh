#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v zsh >/dev/null; then echo "zsh not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
ZSHRC="$WB_SRC/config/zsh/zshrc"
# A stand-in plugin: records that it was loaded and what local.zsh had seen by then.
mkplugin() { mkdir -p "$(dirname "$1")"; printf 'WB_HL_LOADED=1\nWB_HL_SAW_LOCAL=${WB_LOCAL_RAN:-no}\n' > "$1"; }
run() { HOME="$1" zsh -f -c "source '$ZSHRC' 2>&1; print -r -- \"loaded=\${WB_HL_LOADED:-no} saw_local=\${WB_HL_SAW_LOCAL:-na}\"" 2>&1 | tail -1; }

echo "syntax highlighting is optional"
H1="$T_DIR/none"; mkdir -p "$H1"
assert_eq "no plugin installed: the shell still starts and nothing is loaded" "loaded=no saw_local=na" "$(run "$H1")"

echo "found in each supported location"
for rel in ".oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ".zsh/zsh-syntax-highlighting"; do
  H="$T_DIR/h-$(echo "$rel" | tr '/.' '__')"; mkdir -p "$H"; mkplugin "$H/$rel/zsh-syntax-highlighting.zsh"
  case $(run "$H") in loaded=1*) t_ok "loaded from ~/$rel";; *) t_fail "not loaded from ~/$rel";; esac
done

echo "it is loaded after local.zsh (a highlighter must come last)"
H3="$T_DIR/order"; mkdir -p "$H3/.config/zsh"
mkplugin "$H3/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
echo 'WB_LOCAL_RAN=yes' > "$H3/.config/zsh/local.zsh"
assert_eq "local.zsh ran before the plugin" "loaded=1 saw_local=yes" "$(run "$H3")"

case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac
t_done
