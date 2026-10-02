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
# Scan what git would publish (tracked plus new, not ignored); local tool state such as .tokenize/ is ignored and stays out.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  hits=$(git ls-files -z -co --exclude-standard | xargs -0 grep -n -I -E '/Users/[A-Za-z]|/home/[a-z]' 2>/dev/null | grep -v -e 'tests/defaults.test.sh' -e 'linuxbrew' -e '/home/dot_' | head -3)
else
  hits=$(grep -rn -I -E '/Users/[A-Za-z]|/home/[a-z]' . --exclude-dir=.git --exclude=defaults.test.sh | grep -v -e 'linuxbrew' -e '/home/dot_' | head -3)
fi
assert_eq "no /Users/<name> or /home/<name>" "" "$hits"

echo "agent state and credentials are never part of the source tree"
bad=$(find home -type f \( -name 'auth.json' -o -name '.credentials.json' -o -name 'history*' -o -name '*.sqlite*' -o -name 'settings.local.json' -o -name 'oauth_creds.json' -o -name 'installation_id' \) -o -path '*/sessions/*' -o -path '*/projects/*/*.jsonl' | head -3)
assert_eq "no auth, history, session or database files under home/" "" "$bad"
bad=$(find home -type f \( -name 'settings.json' -o -name 'config.toml' \) -path '*/dot_claude/*' -o -type f -name 'config.toml' -path '*/dot_codex/*' | head -3)
assert_eq "the agents' own settings (machine paths, proxies, tools rewrite them) are not tracked" "" "$bad"

t_done
