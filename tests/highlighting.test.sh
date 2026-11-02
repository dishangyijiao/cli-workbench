#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v zsh >/dev/null; then echo "zsh not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
# A stand-in plugin: records that it was loaded and what local.zsh had seen by then.
mkplugin() { mkdir -p "$(dirname "$1")"; printf 'WB_HL_LOADED=1\nWB_HL_SAW_LOCAL=${WB_LOCAL_RAN:-no}\n' > "$1"; }
run() { t_render "$1"; HOME="$1" zsh -f -c "source '$1/.zshrc' 2>&1; print -r -- \"loaded=\${WB_HL_LOADED:-no} saw_local=\${WB_HL_SAW_LOCAL:-na}\"" 2>&1 | tail -1; }

echo "syntax highlighting is optional"
H1="$T_DIR/none"; mkdir -p "$H1"
assert_eq "no plugin installed: the shell still starts and nothing is loaded" "loaded=no saw_local=na" "$(run "$H1")"

echo "found in each supported location"
for rel in ".oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ".zsh/zsh-syntax-highlighting"; do
  H="$T_DIR/h-$(echo "$rel" | tr '/.' '__')"; mkdir -p "$H"; mkplugin "$H/$rel/zsh-syntax-highlighting.zsh"
  case $(run "$H") in loaded=1*) t_ok "loaded from ~/$rel";; *) t_fail "not loaded from ~/$rel";; esac
done

echo "found in the system locations (a distro package installs there)"
# A test cannot write to /usr/share, so run a copy of the rendered .zshrc with /usr/share/ moved under the home directory.
# The search loop is the real one; only the root of the system path changes.
run_rooted() {
  t_render "$1"; sed "s#/usr/share/#$1/usr/share/#g" "$1/.zshrc" > "$1/.zshrc.rooted"
  HOME="$1" zsh -f -c "source '$1/.zshrc.rooted' 2>&1; print -r -- \"loaded=\${WB_HL_LOADED:-no}\"" 2>&1 | tail -1
}
for sys in "zsh-syntax-highlighting:Debian/Ubuntu" "zsh/plugins/zsh-syntax-highlighting:Arch/Omarchy"; do
  rel=${sys%%:*}; name=${sys#*:}
  H="$T_DIR/sys-$(echo "$rel" | tr '/.' '__')"; mkdir -p "$H"; mkplugin "$H/usr/share/$rel/zsh-syntax-highlighting.zsh"
  assert_eq "loaded from /usr/share/$rel ($name)" "loaded=1" "$(run_rooted "$H")"
done

echo "it is loaded after local.zsh (a highlighter must come last)"
H3="$T_DIR/order"; mkdir -p "$H3/.config/zsh"
mkplugin "$H3/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
echo 'WB_LOCAL_RAN=yes' > "$H3/.config/zsh/local.zsh"
assert_eq "local.zsh ran before the plugin" "loaded=1 saw_local=yes" "$(run "$H3")"

case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac
t_done
