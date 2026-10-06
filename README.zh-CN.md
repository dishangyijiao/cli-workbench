# cli-workbench

[![tests](https://github.com/dishangyijiao/cli-workbench/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/dishangyijiao/cli-workbench/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) | 简体中文

**给 AI 编码代理用的终端工作台。** Claude Code、Codex、Gemini CLI、Grok CLI 这些都是读写纯文本的命令行程序，所以运行它们最合适的地方是一个你完全掌控的终端：每个项目一个 tmux 会话，编辑器紧挨着代理，用 ripgrep、fzf、jq 处理文本，所有设置都在一个你能读、能 diff、能 fork 的 Git 仓库里。这个仓库就是这套环境，用 [chezmoi](https://www.chezmoi.io) 部署。

```
  prefix + P  ->  选一个项目  ->  一个 tmux 会话，每个仓库一个窗口
 ┌─────────────────┬─────────────────┐
 │                 │  claude / codex │   第一个已安装的代理在这里启动，
 │  nvim           │  gemini / grok  │   工作目录就是项目目录
 │                 ├─────────────────┤
 │                 │  shell          │
 └─────────────────┴─────────────────┘
```

## 为什么它是工作台，而不只是 dotfiles

| | |
|---|---|
| **项目 → 会话，代理包含在内** | `~/dev/projects` 下的每个目录是一个工作台。包含多个仓库的文件夹算**一个**工作台，每个仓库一个窗口，每个窗口都有自己的代理窗格。不需要登记：直接从目录树发现。自动探测 `claude`、`codex`、`gemini`、`grok`（用 `WORKSPACE_SWITCH_AGENTS` 扩展候选，用 `WORKSPACE_SWITCH_AGENT` 指定某一个，设为 `none` 关闭）。 |
| **一路都是纯文本** | 设置、历史、笔记和代理的指令都是文件。工具是 `rg`、`fzf`、`jq`、`nvim` 和 `git`；没有 GUI 状态，没有会丢的数据库。**同一份指令文本部署给所有代理**（`CLAUDE.md`、`AGENTS.md`、`GEMINI.md`），你的私人规则从一个不入库的文件追加在后面。 |
| **可以放心公开** | 代理需要 API 密钥，而密钥最容易通过 dotfiles 泄露。`scripts/privacy-scan` 在 pre-commit 钩子里运行，CI 里再跑一次，能识别 Anthropic（Claude）、OpenAI、Google（Gemini）、xAI（Grok）的密钥，以及 GitHub 和 AWS 令牌、私钥、个人路径和邮箱地址；pre-push 钩子还会扫描提交元数据（作者、提交者、提交说明）。tmux 窗格内容默认不落盘。密钥放在不入库的文件里。 |
| **可回退** | 每次 `chezmoi apply` 之前，会把将被替换的文件备份到 `~/.cli-workbench-backup/`，并附恢复说明。 |
| **承诺都有测试** | 下面的快速开始会在临时 home 目录里端到端运行（macOS 和 Ubuntu）。代理窗格（用替身代理）、备份和隐私扫描各有自己的测试。 |

**目前针对代理的部分有这些：** 工作台切换器可以启动这四个代理中的任何一个；状态栏（`~/.claude/statusline.sh`）和 mod（见下文）只适用于 Claude Code；共享的指令文本能到达 Claude Code、Codex 和 Gemini CLI（Grok CLI 没有接入：尚不清楚它读哪个指令文件）；各代理的完整设置文件有意不纳入；Codex 的通用界面偏好会合并到本机配置，见下文。本仓库不负责安装这些代理。

> **它是什么：** 一个个人 dotfiles 仓库，结构是 chezmoi 源目录。你 fork 它，修改 `home/`，把它变成你自己的。
>
> **它不是什么：** 不是包管理器、不是一键安装器、不是主题包，也不是代理框架。它不会安装软件，也不管理密钥。

## 使用条件与适用范围

| | |
|---|---|
| **平台** | **macOS** 是主要平台（在 macOS 26、Apple Silicon 上测试）。zsh、tmux 配置在 **Ubuntu 24.04** 上也通过了完整测试和首次使用流程（在容器中验证）；Ghostty 配置和 Homebrew 的 cask 是面向 macOS 的。不支持 Windows。 |
| **Shell** | zsh 5.8 及以上（在 5.9 上测试）。辅助脚本兼容 bash 3.2，也就是 macOS 自带的 bash 就够用。 |
| **tmux** | 建议 3.2 及以上（在 3.5a 上测试）。更旧的版本仍能加载配置，只是少了工作台切换键。 |
| **必需** | `git` 和 [`chezmoi`](https://www.chezmoi.io/install/)（`brew install chezmoi`） |
| **可选** | `fzf`（0.48+ 才有 shell 集成）、`zoxide`、`starship`、`zsh-syntax-highlighting`、`jq`（状态栏用）、`translate-shell`（翻译弹窗）、[Ghostty](https://ghostty.org) 加一款 Nerd Font、Homebrew |

**它会在你的机器上做的改动：** 仅限 [`home/`](home) 下由 chezmoi 部署的文件（见下表）、使用自带 `zshrc` 后 `~/.cache/zsh/` 里的 zsh 补全缓存，以及被替换文件的备份 `~/.cli-workbench-backup/<时间戳>/`（chezmoi 自己不备份，见“安全模型”）。

## 快速开始

```sh
brew install chezmoi
git clone https://github.com/dishangyijiao/cli-workbench.git ~/dev/cli-workbench   # 或你的 fork；放在哪里都可以

chezmoi init --source ~/dev/cli-workbench   # 把这个克隆作为源目录，并安装备份钩子（见下文）

chezmoi diff                       # 只读：$HOME 里将会发生什么变化
chezmoi apply ~/.tmux.conf         # 先只应用一个文件，看看效果
chezmoi apply                      # 再应用全部
```

也可以让 chezmoi 自己克隆：`chezmoi init <你的 GitHub 用户名>/cli-workbench`，然后同样 `diff`、`apply`。

部署的内容（目录结构遵循 [chezmoi 的命名规则](https://www.chezmoi.io/reference/source-state-attributes/)：`dot_` 变成 `.`，`executable_` 设置可执行权限，`private_` 让目录权限为 700）：

| `home/` 中的源 | 目标 | 说明 |
|---|---|---|
| `dot_tmux.conf`、`dot_tmux/scripts/` | `~/.tmux.conf`、`~/.tmux/scripts` | 前缀键 `Ctrl-a`、vi 键位、鼠标、带代理窗格的工作台切换器 |
| `dot_zshrc`、`dot_config/private_zsh/` | `~/.zshrc`、`~/.config/zsh/{path,tmux-autostart}.zsh` | **会替换你的 `.zshrc`**；先把自己的改动挪到 `~/.config/zsh/local.zsh`。安装器（nvm、bun 等）会往 `~/.zshrc` 追加内容，`chezmoi diff` 能看到，请把这类行挪进 `local.zsh` |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` | Catppuccin Mocha 主题、Nerd Font、macOS 标签式标题栏 |
| `dot_claude/executable_statusline.sh` | `~/.claude/statusline.sh` | Claude Code 状态栏（项目、分支、模型、上下文、费用、速率限制）；仅在使用 Claude Code 时需要 |
| `dot_claude/workbench-mods/` | `~/.claude/workbench-mods/` | 两个 Claude Code mod（`chezmoi-guard`、`reply-polish`），作为本地插件市场；只部署，不安装，见“Claude Code mod” |
| `dot_codex/modify_private_config.toml` | `~/.codex/config.toml` | 合并通用状态栏和完成铃铛偏好，保留其他本机设置 |
| `.chezmoitemplates/agent-instructions.md`、`dot_claude/CLAUDE.md.tmpl`、`dot_codex/AGENTS.md.tmpl`、`dot_gemini/GEMINI.md.tmpl` | `~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.gemini/GEMINI.md` | 给所有代理的同一段简短文本：这个工作台怎么运作（配置在仓库里、密钥不进仓库、每个项目一个 tmux 会话）。你自己的规则见“代理指令” |
| `dot_config/git/config` | `~/.config/git/config` | 可移植的 Git 设置；Git 会自动读取这个文件，`~/.gitconfig`（身份、凭据）仍归你自己 |
| `dot_config/nvim/` | `~/.config/nvim` | 可选的 Neovim 配置（lazy.nvim、LSP、Telescope、Git、调试；不含 AI 插件：代理在自己的窗格里运行）；插件在首次启动时安装，需要联网。已有自己的配置，就在你的 fork 里删掉这个目录 |

建议的顺序和需要手动完成的步骤（Homebrew 工具、tmux 插件管理器）见 [`docs/bootstrap.md`](docs/bootstrap.md)。

## 你可能想先改的默认值

这些是个人偏好，不是硬性要求。改 `home/` 里的文件，然后运行 `chezmoi apply`（或 `chezmoi edit --apply ~/.tmux.conf`）。

- **tmux：** 前缀键是 `Ctrl-a`（不是 `Ctrl-b`）；vi 风格复制模式；开启鼠标；窗口从 1 开始编号。窗格内容默认**不**保存到磁盘（那样会把窗格里打印过的任何东西，包括令牌，都存下来）；想开启请看 `@resurrect-capture-pane-contents` 旁边的注释。
- **zsh：** 50,000 行共享历史、补全不区分大小写，`starship`、`zoxide`、`fzf` 和 `zsh-syntax-highlighting` 仅在已安装时启用。
- **Ghostty：** Catppuccin Mocha 和 `SauceCodePro Nerd Font Mono`（安装该字体，或者改掉这一行）。

## 把它变成你的

- **每台机器不同的设置**（额外的 PATH、代理、是否开启 tmux 选择器）：把 `templates/local.zsh.example` 复制为 `~/.config/zsh/local.zsh`。chezmoi 不管理它，并且它最后加载。
- **密钥：** 把 `templates/secrets.zsh.example` 复制为 `~/.config/zsh/secrets.zsh`，权限 600，绝不提交。仓库里永远不能出现密钥或令牌。
- **添加另一个工具：** `chezmoi add ~/.config/<工具>/config` 会把文件复制进 `home/`，然后提交。
- **会被程序自己改写的文件**（例如 `:Lazy update` 之后的 `lazy-lock.json`）：变化发生在 `$HOME` 里的副本，仓库不会变。`chezmoi diff` 能看到；用 `chezmoi re-add` 拉回 `home/`。
- **Neovim：** 想用自己的配置，就在你的 fork 里删掉 `home/dot_config/nvim`。

## 命令

```sh
chezmoi diff | status | verify   # home/ 与 $HOME 有什么差异（有差异时 verify 返回非零）
chezmoi doctor                   # chezmoi 自带的健康检查
tests/run.sh                     # 仓库自己的测试，包含在临时 HOME 里端到端运行本快速开始
scripts/privacy-scan [--all]     # 扫描已暂存（或全部已跟踪）文件、或提交元数据（--commits）中的密钥、个人路径和邮箱地址
scripts/lint-shell               # 对仓库里所有 bash/sh 脚本运行 shellcheck（warning 及以上级别）
```

## 安全模型

- `chezmoi diff` 和 `chezmoi apply --dry-run` 不会改动任何东西。
- **每次 apply 之前先备份。** chezmoi 会直接覆盖内容不同的文件，不留副本。`chezmoi init` 会安装一个钩子（[`scripts/backup-before-apply`](scripts/backup-before-apply)），在 apply 之前把将被替换的文件（包括 chezmoi 写入后被你改过的文件）拷到 `~/.cli-workbench-backup/<时间戳>/`。目录权限 700，软链接按软链接保存，`RESTORE` 里每个文件一条可直接复制的恢复命令。没有要改的文件时什么都不创建；备份失败则拒绝 apply；`--dry-run` 没有任何副作用。
- 钩子写在 `chezmoi init` 生成的配置里。如果你只是手写了 `chezmoi.toml`，或者没运行过 `init` 就用 `chezmoi apply --source ...`，则**没有**备份。
- 它只会碰上表里的目标，除非你主动要求（`chezmoi destroy`），否则不会删除任何东西。
- `scripts/privacy-scan` 负责检查你提交的内容；详见上文“可以放心公开”。

## 代理指令

Claude Code、Codex 和 Gemini CLI 都会从各自的主目录读取一个纯文本指令文件。这里它们由**同一个**源 `home/.chezmoitemplates/agent-instructions.md` 生成，所以各个代理得到的是关于这台机器的同一套事实，以及同一套工程原则：单一事实来源且各层只写差异、最小权限、写进文件而不只靠对话、够用的最简方案、先有证据再说完成并留好退路。

- **你自己的规则**写在 `~/.config/cli-workbench/agent-instructions.local.md`。它不入库，所以个人偏好不会进入公开的 fork；它会被追加在三个文件的共享文本之后。删掉这个文件，下一次 `chezmoi apply` 就会移除其中的文本。
- **已有的文件：** 你现有的 `~/.claude/CLAUDE.md`（以及另外两个）在 `apply` 时会被替换，替换前会先备份。想保持原样，请事先把内容挪进本地文件。
- **改源，不要改部署后的文件。** 工具追加到 `~/.claude/CLAUDE.md` 的内容，会在下一次 apply 时被覆盖。生成的文件不能用 `chezmoi re-add` 拉回。
- **有意不以完整文件纳入：** `settings.json`、`config.toml`、`auth.json`、历史、会话和数据库。它们包含机器路径、代理和凭据，而且工具会自己改写。如果 `home/` 下出现这类文件，有测试会失败。
- 要公开你自己的准则，请在你的 fork 里把它们放进共享源，而不是未被跟踪的本地文件。

## Codex 通用偏好迁移

`home/dot_codex/modify_private_config.toml` 将五项界面设置合并到 `~/.codex/config.toml`：状态栏（模型、目录、会话名、5 小时和每周剩余额度）、状态栏颜色，以及不受焦点限制的任务完成终端响铃通知。配合现有 tmux 响铃设置，Ghostty 可以给后台标签加上铃铛标记。

新机器单独安装 Codex，按常规流程执行 `chezmoi init` / `chezmoi apply`，然后登录 Codex。配置不存在时会创建；已有模型选择、本机路径、通知命令、项目信任和其他设置会保留，凭据和会话不会迁移。应用后重启已有 Codex CLI，可用 `codex resume --last` 继续会话。

修改合并模板即可调整这些共享偏好。在 Codex 内修改这五项设置后，下次 apply 会恢复模板中的值。不要用 `chezmoi add` 或 `re-add` 将本机完整配置复制进仓库。需要更新值时会重新生成 TOML，因此原注释和排版会丢失；值已匹配的文件保持原样。现有的 apply 前备份机制会在替换前保存原文件。TOML 格式错误时会停止合并，不覆盖原文件。

## Claude Code mod

*mod* 是一种 Claude Code 插件，它的行为写在一个小的 TypeScript 文件里，Claude Code 在事件发生时调用它：比如一个工具即将运行、一条回复即将绘制。本仓库带了两个，放在 `home/dot_claude/workbench-mods/`，组成一个本地*插件市场*（Claude Code 从中安装插件的文件夹）：

| mod | 作用 |
|---|---|
| `chezmoi-guard` | 拒绝用 `Edit`、`Write`、`NotebookEdit` 修改 chezmoi 已部署的文件（`~/.zshrc`、`~/.tmux.conf` 等），并指出该改哪个源文件，这样下一次 `chezmoi apply` 不会覆盖你的修改。已部署文件与源不一致时，在提示栏上方显示一行提示（来自 `chezmoi status`）。它看不到通过 Bash 做的修改（`sed -i`、`> 文件`）。chezmoi 不存在或执行失败时，它什么都不拦。 |
| `reply-polish` | 为宽终端排版助手的回复。文字是一栏，最宽 80 格（约 40 个汉字）且不超过窗口的 72%，左对齐，并整体居中。标题加粗，前两级为青色；列表用 `•` 和 `◦`；表格在放得下时用制表符画出，放不下就变成列表；折行时数字不和单位分开，句号逗号不出现在行首；超过 30 行的代码块缩短为 12 行。只改绘制：已存储的回复和 `ctrl+o` 看到的仍是原文。 |

**每台机器安装一次**（需要 Claude Code 2.1.287 或更新版本；`chezmoi apply` 只部署文件，不会安装任何东西）：

```sh
chezmoi apply                                                   # 部署 ~/.claude/workbench-mods
claude plugin marketplace add ~/.claude/workbench-mods
claude plugin install chezmoi-guard@cli-workbench --scope user
claude plugin install reply-polish@cli-workbench --scope user
```

然后重启 Claude Code，或在运行中的会话里执行 `/reload-plugins`。

- **修改 mod：** 在 `home/dot_claude/workbench-mods/` 下改，执行 `chezmoi apply`，再 `/reload-plugins`。文件夹形式的插件市场直接从文件夹读取，所以不需要提升版本号。`claude plugin disable <名称>` 临时关闭，`claude plugin uninstall <名称>` 卸载。
- **测试：** `tests/mods.test.sh` 总会检查插件市场的结构。装有 Claude Code 时，还会运行 `claude plugin validate` 和每个 mod 自带的测试（`claude plugin test`）；没装则跳过这一部分。
- **信任：** mod 能看到每一次工具调用和每一条回复，并以你的权限运行。安装前请先读源码，每个 mod 只有几百行。
- **稳定性：** mod 的 API 处于早期阶段，不同版本之间会变化。这两个 mod 是用 Claude Code 2.1.289 开发和测试的。使用 `--safe-mode` 或 `--bare` 时 mod 不会加载。
- **有意不纳入版本控制：** Claude Code 加载 mod 时写进 `.claude-plugin/types/` 的类型声明文件。

## 工作台切换器（tmux）

按 `前缀键` 再按 `P`（`Ctrl-a P`），弹出 `~/dev/projects` 下的选择器。根目录下的每个直接子目录都是一个工作台，会打开成一个 tmux 会话：左边编辑器，右边上面是 AI 代理、下面是 shell。不是仓库、但里面包含多个仓库的目录（多仓库产品）算**一个**工作台，每个仓库一个窗口。选择已存在的工作台只会切换过去。需要 tmux 3.2+ 和 `fzf`。

- **代理窗格：** 在项目目录里启动 `claude codex gemini grok` 中第一个已安装的。一个都没装时，窗口只有编辑器和 shell。`WORKSPACE_SWITCH_AGENT="claude --continue"` 指定某一个（可带参数），`none` 关闭，`WORKSPACE_SWITCH_AGENTS="aider claude"` 修改候选及顺序。在 `home/dot_tmux.conf` 里用 `set-environment -g` 设置，与 `WORKSPACE_ROOTS` 放在一起。
- **根目录：** 取消 `home/dot_tmux.conf` 里 `WORKSPACE_ROOTS` 的注释，可以扫描其他目录。
- 详细说明在 `home/dot_tmux/scripts/executable_workspace-switch.sh` 开头的注释里。

## 代码弹窗（tmux）

不离开代理所在的窗格就能看代码。两个键都会在当前窗格上方弹出 Neovim，目录就是该窗格的目录；关掉 Neovim，弹窗随之关闭，回到原处。需要 tmux 3.2+。

- 先按 `prefix` 再按 `e`：**浏览**项目，用平常的 Neovim 按键（`<leader>ff` 找文件、`<leader>fg` 全文搜索、`<leader>e` 文件树）。`:qa` 关闭。
- 先按 `prefix` 再按 `g`：**查看改动**。用 Telescope 列出当前分支自离开默认分支（`origin/HEAD`，否则 `origin/main`、`main` 等）以来改过的每个文件：已提交、未提交、已删除和未跟踪的都算，并分别标注，预览区是带颜色的 diff。按 `Enter` 会在新标签页里打开该文件，左边是它在分叉点时的版本，用 Neovim 自带的 diff 模式对照（已删除的文件：左边是旧版本，右边为空）（`]c`/`[c` 在改动之间跳转）。在 Neovim 里也可以用 `:Changes` 或 `<leader>gv` 打开同一个列表。`:qa` 关闭弹窗。不在 Git 仓库里时会给出提示。不需要额外插件。
- 脚本是 `home/dot_tmux/scripts/executable_code-popup.sh`；tmux 只传给它窗格 ID，从不传目录名。

## 翻译选中的文字（tmux）

用鼠标（或在复制模式里按 `v` ... `y`）选中一段英文，再按 `前缀键` 加 `t`（`Ctrl-a t`）。弹窗里会显示翻译，不用离开正在阅读的窗格。单个单词给出词典条目，更长的文字给出译文。按 `q` 关闭弹窗。

- **需要：** tmux 3.2+ 和 `translate-shell`（`brew install translate-shell`；没装时弹窗会提示）。
- **隐私：** 选中的文字会发给翻译服务（默认是 Google；失败时会再问一次 Bing）。不要用在不能发出去的文字上。
- **语言：** `LOOKUP_LANG` 设置目标语言（默认 `zh-CN`）。细节见 `home/dot_tmux/scripts/executable_lookup.sh` 开头的注释。

## 想法收件箱（tmux）

一有想法就记下来，不用离开当前窗格，也不打断正在干活的代理。先按 `prefix` 再按 `a`（`Ctrl-a a`），输入一行，回车；弹窗关闭，回到原处。空行表示取消。在 shell 里，`idea 一些文字` 效果相同（只敲 `idea` 会提示你输入）。需要 tmux 3.2+。

- **记在哪里：** 所有项目共用 `~/.config/cli-workbench/inbox.md`（私人文件，权限 600，不在本仓库里），每个想法一行：`- [ ] 2026-10-06 17:42 · ~/dev/projects/foo · 想法`。项目是仓库的根目录；在 worktree 里则是它所属的仓库；窗格已不存在时记为 `?`。
- **输入什么都安全：** 文字原样保存，绝不会被执行。写入失败时弹窗不会关闭，并把你的想法再显示一遍。
- **整理：** 让代理"处理收件箱"。规则：先把文件复制成带时间戳的备份（权限 600）；只改它处理的那几行，把 `- [ ]` 改成 `- [x]`，从不删除；改完检查之前的每一行都还在；任何要发到本机以外的操作（比如开 GitHub issue）先问你。

## 卸载 / 恢复

从 `~/.cli-workbench-backup/<时间戳>/RESTORE` 里按文件恢复（每个文件一条命令），或者删掉不想要的文件。`chezmoi unmanage <目标>` 可以让它不再管理某个文件。

## 故障排查

- Debian/Ubuntu：shell 启动时出现 `compinit: initialization aborted` 或“insecure directories”，来自系统的 `/etc/zsh/zshrc`：当 `/usr/share/zsh` 权限过松时，它会先于你的配置运行自己的 `compinit`。这里的 zshrc 已经运行了 `compinit`，所以在 `~/.zshenv` 里加上 `skip_global_compinit=1`（或者修正权限，参见 `compaudit`）。
- `chezmoi: ... has changed since chezmoi last wrote it`：你改过已部署的文件。先 `chezmoi diff`，然后 `chezmoi re-add`（保留你的改动）或 `chezmoi apply --force`（采用仓库里的版本；你的改动会先进入备份）。
- tmux 配置问题：`tmux -L test -f ~/.tmux.conf new-session -d` 会在独立 socket 上加载它；`tmux -L test show-messages` 会打印错误。
- 更多内容见 [`docs/architecture.md`](docs/architecture.md)。

## 参与贡献

欢迎提交 issue 和 pull request，详见 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请看 [SECURITY.md](SECURITY.md)，不要公开提 issue。版本之间的变化记录在 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

[MIT](LICENSE)
