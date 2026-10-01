#!/usr/bin/env bash
# Guards for what a stranger gets by default. These fail if a risky default or a machine-specific path sneaks back in.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
cd "$WB_SRC" || exit 1

echo "tmux does not save pane contents to disk by default"
case $(grep -E "^set .*@resurrect-capture-pane-contents" home/dot_tmux.conf) in      # real settings only, not comments
  *"'on'"*) t_fail "pane contents are saved by default (could store tokens in plaintext)" ;;
  *) t_ok "pane content capture is not on by default" ;;
esac

echo "zsh defaults are not intrusive"
assert "tmux autostart is opt-in" grep -q 'WB_TMUX_AUTOSTART:-0' home/dot_zshrc
refute "the default zshrc sets no proxy" grep -q -i 'proxy' home/dot_zshrc

echo ".gitignore keeps secrets and per-machine files out of the repo"
for pat in local.zsh secrets.zsh .env '*.pem' '*.key' '*.p12' .DS_Store; do
  assert ".gitignore lists $pat" grep -qxF "$pat" .gitignore
done
refute "the tracked templates are not ignored by those patterns" grep -qxF 'templates' .gitignore

echo "no absolute home directories in tracked files"
hits=$(grep -rn -I -E '/Users/[A-Za-z]|/home/[a-z]' . --exclude-dir=.git --exclude=defaults.test.sh | grep -v -e 'linuxbrew' -e '/home/dot_' | head -3)
assert_eq "no /Users/<name> or /home/<name>" "" "$hits"

t_done
