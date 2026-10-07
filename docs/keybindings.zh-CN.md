# 按键表

[English](keybindings.md) | 简体中文

这个工作台里最常用的按键，一页纸，方便打印。`tests/keybindings.test.sh` 会检查：这里的每个 `prefix` 键在部署后的 tmux 配置里都有绑定，每个 `<leader>` 键在 Neovim 里都有映射，中英两份列出的按键完全一致。

记法：`C-a` = 按住 Ctrl 再按 a。`prefix` 就是 `C-a`：先按它，松开，再按后面的键。`M-1` = Option+1，需要终端把 Option 当作 Alt 发送（Ghostty：`macos-option-as-alt`）。Neovim 里的 `<leader>` 是空格键。带 ★ 的是每天都会用的，先练这些。

## tmux

### 每天都用

| 按键 | 作用 |
|---|---|
| ★ `prefix P` | 选择项目（fzf），打开或切换到它的会话 |
| ★ `prefix e` | 弹出 Neovim 浏览代码（`:qa` 关闭） |
| ★ `prefix g` | 弹出本分支改过的文件，可预览 diff（`:qa` 关闭） |
| ★ `prefix a` | 记一个想法：输入一行，`Enter`（空行取消）；shell 里用 `idea 文字` |
| ★ `prefix t` | 翻译刚选中的文字（弹窗，`q` 关闭） |
| ★ `C-h` `C-j` `C-k` `C-l` | 在窗格之间移动（在 Neovim 里也通用） |
| ★ `prefix w` | 树状列表，选择会话或窗口 |

### 窗口和窗格

| 按键 | 作用 |
|---|---|
| `prefix c` | 在当前目录新建窗口 |
| `prefix 1` … `prefix 9` | 跳到第 1 … 9 个窗口 |
| `prefix ,` | 重命名窗口 |
| `prefix <` / `prefix >` | 窗口往左 / 往右挪 |
| `prefix \|` | 左右分屏 |
| `prefix -` | 上下分屏 |
| `prefix h` `prefix j` `prefix k` `prefix l` | 选择左 / 下 / 上 / 右的窗格 |
| `prefix H` `prefix J` `prefix K` `prefix L` | 调整窗格大小（可连按） |
| `M-1` … `M-9` | 不按 prefix，直接跳到第 1 … 9 个窗格 |
| `prefix z` | 窗格放大 / 还原 |
| `prefix x` | 关闭窗格（会确认） |
| `prefix m` | 同时往所有窗格打字（再按一次停止） |

### 会话

| 按键 | 作用 |
|---|---|
| `prefix N` | 用当前目录名新建会话并切过去 |
| `prefix S` | 按名字新建或进入会话 |
| `prefix X` | 关闭当前会话（会确认） |
| `prefix d` | 离开 tmux，会话在后台继续 |
| `prefix r` | 重新加载 tmux 配置 |

### 复制模式（Vim 按键）

| 按键 | 作用 |
|---|---|
| ★ `prefix v` | 进入复制模式并开始选择 |
| `prefix [` | 进入复制模式，往上翻看输出 |
| `h` `j` `k` `l`、`/` | 移动、搜索 |
| `v` / `r` / `y` | 开始选择 / 切换矩形选择 / 复制并退出 |
| `q` | 退出复制模式 |

## Neovim（`<leader>` 是空格）

### 找文件、搜索（Telescope）

| 按键 | 作用 |
|---|---|
| ★ `<leader>ff` | 按文件名找文件 |
| ★ `<leader>fg` | 全项目搜索文字 |
| ★ `<leader>fw` | 搜索光标下的单词 |
| `<leader>fb` | 已打开的文件 |
| `<leader>fh` | 输入一段文字，在项目里搜索 |
| `<leader>fs` | 当前文件里的符号 |

列表里：`C-n` / `C-p` 上下移动，`Enter` 打开，`Esc` 关闭。

### 文件树（nvim-tree）

| 按键 | 作用 |
|---|---|
| ★ `<leader>e` | 打开 / 关闭文件树 |
| `<leader>fe` | 在文件树里定位当前文件 |
| `Enter` | 打开文件或目录 |
| `a` / `d` / `r` | 新建 / 删除 / 重命名 |
| `c` / `p` | 复制 / 粘贴 |
| `Y` | 复制相对路径 |
| `?` | 文件树的全部按键 |

### 读代码（LSP，装了语言服务器时可用）

| 按键 | 作用 |
|---|---|
| ★ `gd` | 跳到定义 |
| ★ `K` | 显示类型和文档 |
| ★ `C-o` / `C-i` | 跳回 / 跳前 |
| `gr` | 引用 |
| `gi` | 实现 |
| `<leader>fr` | 引用（Telescope 列表） |
| `<leader>rn` | 重命名符号 |
| `<leader>ca` | 代码操作 |
| `<leader>fd` | 诊断列表 |

### Git

| 按键 | 作用 |
|---|---|
| ★ `<leader>gv` | 本分支改过的文件（同 `prefix g`） |
| `<leader>gj` / `<leader>gk` | 文件里的下一处 / 上一处改动 |
| `<leader>gp` | 预览这一处改动 |
| `<leader>gb` | 这一行是谁、在哪次提交里改的 |
| `<leader>gt` | git status 列表 |
| `<leader>gc` | 提交历史 |
| `<leader>gB` | 分支列表 |

### 对照查看改动（在改动列表里按 `Enter` 之后）

| 按键 | 作用 |
|---|---|
| ★ `]c` / `[c` | 下一处 / 上一处差异 |
| `C-w w` | 在左右两边之间切换 |
| `:tabclose` | 关闭这一组对照 |
| `gt` / `gT` | 下一个 / 上一个标签页 |

### Markdown（render-markdown.nvim）

打开 `.md` 文件，会在同一个窗口里直接显示渲染后的效果：标题、列表、表格、代码块和引用都以带样式的文字呈现。文件内容不变，光标所在的行会显示原始源码，方便编辑。

| 按键 | 作用 |
|---|---|
| ★ `<leader>mp` | 关闭 / 打开渲染（仅 Markdown 文件） |

### 其他

| 按键 | 作用 |
|---|---|
| `<leader>l` | 清除搜索高亮 |
| `:qa` | 退出 Neovim（也用来关闭弹窗） |

## zsh

| 按键 | 作用 |
|---|---|
| ★ `C-r` | 搜索历史命令（fzf） |
| ★ `C-t` | 选文件（fzf），把路径插入命令行 |
| `M-c` | 选目录（fzf）并进入 |
| `↑` / `↓` | 按已输入的开头翻历史命令 |
| `C-a` / `C-e` | 光标到行首 / 行尾（在 tmux 里行首要按 `C-a C-a`） |
| `C-w` / `C-u` | 删除前一个词 / 整行 |

## 忘了某个键？

tmux：`prefix ?` 列出全部绑定。Neovim：在文件树里按 `?`，或用 `:Telescope keymaps`。
