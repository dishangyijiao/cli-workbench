# Static PATH additions. Directories that do not exist are skipped, duplicates are removed by `typeset -gU path`.
# Covers ~/.local/bin and Homebrew on Apple Silicon, Intel and Linux. Machine-specific entries belong in
# ~/.config/zsh/local.zsh (not tracked).
_wb_p=()
for _wb_d in \
  $HOME/.local/bin \
  /opt/homebrew/bin /opt/homebrew/sbin \
  /usr/local/bin \
  /home/linuxbrew/.linuxbrew/bin
do
  [[ -d $_wb_d ]] && _wb_p+=($_wb_d)
done
path=($_wb_p $path)
unset _wb_p _wb_d
export PATH
