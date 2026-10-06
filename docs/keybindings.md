# Keybindings

English | [简体中文](keybindings.zh-CN.md)

The keys you use most in this workbench, one page to print. `tests/keybindings.test.sh` checks that every `prefix` key here is bound in the deployed tmux config and every `<leader>` key is mapped in Neovim, and that both languages list the same keys.

Notation: `C-a` means hold Ctrl and press a. `prefix` is `C-a`: press it, let go, then press the next key. `M-1` means Option+1, which needs the terminal to send Option as Alt (Ghostty: `macos-option-as-alt`). In Neovim `<leader>` is the space bar. ★ marks the daily ones; learn those first.

## tmux

### Daily

| Key | Action |
|---|---|
| ★ `prefix P` | Pick a project (fzf) and open or switch to its session |
| ★ `prefix e` | Neovim in a popup, to browse code (`:qa` closes it) |
| ★ `prefix g` | The files this branch changed, with a diff preview, in a popup (`:qa` closes it) |
| ★ `prefix a` | Write an idea down: one line, `Enter` (an empty line cancels); `idea TEXT` in a shell |
| ★ `prefix t` | Translate the text you just selected, in a popup (`q` closes it) |
| ★ `C-h` `C-j` `C-k` `C-l` | Move between panes (also inside Neovim) |
| ★ `prefix w` | Tree of sessions and windows to pick from |

### Windows and panes

| Key | Action |
|---|---|
| `prefix c` | New window in the current directory |
| `prefix 1` … `prefix 9` | Go to window 1 … 9 |
| `prefix ,` | Rename the window |
| `prefix <` / `prefix >` | Move the window left / right |
| `prefix \|` | Split left / right |
| `prefix -` | Split top / bottom |
| `prefix h` `prefix j` `prefix k` `prefix l` | Select the pane left / below / above / right |
| `prefix H` `prefix J` `prefix K` `prefix L` | Resize the pane (repeatable) |
| `M-1` … `M-9` | Go to pane 1 … 9 without the prefix |
| `prefix z` | Zoom the pane in / out |
| `prefix x` | Close the pane (asks first) |
| `prefix m` | Type into all panes at once (press again to stop) |

### Sessions

| Key | Action |
|---|---|
| `prefix N` | New session named after the current directory, and switch to it |
| `prefix S` | New or existing session by name |
| `prefix X` | Kill the current session (asks first) |
| `prefix d` | Detach; the session keeps running |
| `prefix r` | Reload the tmux config |

### Copy mode (Vim keys)

| Key | Action |
|---|---|
| ★ `prefix v` | Enter copy mode and start selecting |
| `prefix [` | Enter copy mode to scroll back |
| `h` `j` `k` `l`, `/` | Move, search |
| `v` / `r` / `y` | Start selection / toggle rectangle / copy and leave |
| `q` | Leave copy mode |

## Neovim (`<leader>` is space)

### Find and search (Telescope)

| Key | Action |
|---|---|
| ★ `<leader>ff` | Find a file by name |
| ★ `<leader>fg` | Search text in the project |
| ★ `<leader>fw` | Search the word under the cursor |
| `<leader>fb` | Open buffers |
| `<leader>fh` | Type a text, search it in the project |
| `<leader>fs` | Symbols in this file |

In a list: `C-n` / `C-p` move, `Enter` opens, `Esc` closes.

### File tree (nvim-tree)

| Key | Action |
|---|---|
| ★ `<leader>e` | Open / close the file tree |
| `<leader>fe` | Show the current file in the tree |
| `Enter` | Open a file or a directory |
| `a` / `d` / `r` | Create / delete / rename |
| `c` / `p` | Copy / paste |
| `Y` | Copy the relative path |
| `?` | All file tree keys |

### Read code (LSP, when a language server is installed)

| Key | Action |
|---|---|
| ★ `gd` | Go to definition |
| ★ `K` | Hover: type and documentation |
| ★ `C-o` / `C-i` | Jump back / forward |
| `gr` | References |
| `gi` | Implementation |
| `<leader>fr` | References in a Telescope list |
| `<leader>rn` | Rename the symbol |
| `<leader>ca` | Code action |
| `<leader>fd` | Diagnostics list |

### Git

| Key | Action |
|---|---|
| ★ `<leader>gv` | The files this branch changed (same as `prefix g`) |
| `<leader>gj` / `<leader>gk` | Next / previous change in the file |
| `<leader>gp` | Preview this change |
| `<leader>gb` | Who changed this line, in which commit |
| `<leader>gt` | git status list |
| `<leader>gc` | Commit history |
| `<leader>gB` | Branches |

### Comparing a change (after `Enter` in the change list)

| Key | Action |
|---|---|
| ★ `]c` / `[c` | Next / previous difference |
| `C-w w` | Switch between the two sides |
| `:tabclose` | Close this comparison |
| `gt` / `gT` | Next / previous tab |

### Other

| Key | Action |
|---|---|
| `<leader>l` | Clear the search highlight |
| `:qa` | Quit Neovim (closes a popup) |

## zsh

| Key | Action |
|---|---|
| ★ `C-r` | Search the command history (fzf) |
| ★ `C-t` | Pick a file (fzf) and insert its path |
| `M-c` | Pick a directory (fzf) and go there |
| `↑` / `↓` | History that starts with what you typed |
| `C-a` / `C-e` | Start / end of the line (inside tmux, `C-a C-a` for the start) |
| `C-w` / `C-u` | Delete the previous word / the whole line |

## Forgot a key?

tmux: `prefix ?` lists every binding. Neovim: `?` in the file tree, or `:Telescope keymaps`.
