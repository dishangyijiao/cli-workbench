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
| **一路都是纯文本** | 设置、历史、笔记和代理的指令都是文件。工具是 `rg`、`fzf`、`jq`、`nvim` 和 `git`；没有 GUI 状态，没有会丢的数据库。 |
| **可以放心公开** | 代理需要 API 密钥，而密钥最容易通过 dotfiles 泄露。`scripts/privacy-scan` 在 pre-commit 钩子里运行，CI 里再跑一次，能识别 Anthropic（Claude）、OpenAI、Google（Gemini）、xAI（Grok）的密钥，以及 GitHub 和 AWS 令牌、私钥、个人路径和邮箱地址。tmux 窗格内容默认不落盘。密钥放在不入库的文件里。 |
| **可回退** | 每次 `chezmoi apply` 之前，会把将被替换的文件备份到 `~/.cli-workbench-backup/`，并附恢复说明。 |
| **承诺都有测试** | 下面的快速开始会在临时 home 目录里端到端运行（macOS 和 Ubuntu）。代理窗格（用替身代理）、备份和隐私扫描各有自己的测试。 |

**如实说明，目前针对代理的部分有这些：** 工作台切换器可以启动这四个代理中的任何一个；状态栏（`~/.claude/statusline.sh`）只适用于 Claude Code；Gemini CLI 和 Grok CLI 在这里还没有自己的设置。本仓库不负责安装这些代理。

> **它是什么：** 一个个人 dotfiles 仓库，结构是 chezmoi 源目录。你 fork 它，修改 `home/`，把它变成你自己的。
> **它不是什么：** 不是包管理器、不是一键安装器、不是主题包，也不是代理框架。它不会安装软件，也不管理密钥。

## 使用条件与适用范围

| | |
|---|---|
| **平台** | **macOS** 是主要平台（在 macOS 26、Apple Silicon 上测试）。zsh、tmux 配置在 **Ubuntu 24.04** 上也通过了完整测试和首次使用流程（在容器中验证）；Ghostty 配置和 Homebrew 的 cask 是面向 macOS 的。不支持 Windows。 |
| **Shell** | zsh 5.8 及以上（在 5.9 上测试）。辅助脚本兼容 bash 3.2，也就是 macOS 自带的 bash 就够用。 |
| **tmux** | 建议 3.2 及以上（在 3.5a 上测试）。更旧的版本仍能加载配置，只是少了工作台切换键。 |
| **必需** | `git` 和 [`chezmoi`](https://www.chezmoi.io/install/)（`brew install chezmoi`） |
| **可选** | `fzf`（0.48+ 才有 shell 集成）、`zoxide`、`starship`、`zsh-syntax-highlighting`、`jq`（状态栏用）、[Ghostty](https://ghostty.org) 加一款 Nerd Font、Homebrew |

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
scripts/privacy-scan [--all]     # 扫描已暂存（或全部已跟踪）文件中的密钥、个人路径和邮箱地址
```

## 安全模型

- `chezmoi diff` 和 `chezmoi apply --dry-run` 不会改动任何东西。
- **每次 apply 之前先备份。** chezmoi 会直接覆盖内容不同的文件，不留副本。`chezmoi init` 会安装一个钩子（[`scripts/backup-before-apply`](scripts/backup-before-apply)），在 apply 之前把将被替换的文件（包括 chezmoi 写入后被你改过的文件）拷到 `~/.cli-workbench-backup/<时间戳>/`。目录权限 700，软链接按软链接保存，`RESTORE` 里每个文件一条可直接复制的恢复命令。没有要改的文件时什么都不创建；备份失败则拒绝 apply；`--dry-run` 没有任何副作用。
- 钩子写在 `chezmoi init` 生成的配置里。如果你只是手写了 `chezmoi.toml`，或者没运行过 `init` 就用 `chezmoi apply --source ...`，则**没有**备份。
- 它只会碰上表里的目标，除非你主动要求（`chezmoi destroy`），否则不会删除任何东西。
- `privacy-scan` 在 pre-commit 钩子和 CI 里都会运行，避免密钥、令牌、个人路径和邮箱地址意外进入公开的 fork。

## 工作台切换器（tmux）

按 `前缀键` 再按 `P`（`Ctrl-a P`），弹出 `~/dev/projects` 下的选择器。根目录下的每个直接子目录都是一个工作台，会打开成一个 tmux 会话：左边编辑器，右边上面是 AI 代理、下面是 shell。不是仓库、但里面包含多个仓库的目录（多仓库产品）算**一个**工作台，每个仓库一个窗口。选择已存在的工作台只会切换过去。需要 tmux 3.2+ 和 `fzf`。

- **代理窗格：** 在项目目录里启动 `claude codex gemini grok` 中第一个已安装的。一个都没装时，窗口只有编辑器和 shell，和以前一样。`WORKSPACE_SWITCH_AGENT="claude --continue"` 指定某一个（可带参数），`none` 关闭，`WORKSPACE_SWITCH_AGENTS="aider claude"` 修改候选及顺序。在 `home/dot_tmux.conf` 里用 `set-environment -g` 设置，与 `WORKSPACE_ROOTS` 放在一起。
- **根目录：** 取消 `home/dot_tmux.conf` 里 `WORKSPACE_ROOTS` 的注释，可以扫描其他目录。
- 详细说明在 `home/dot_tmux/scripts/executable_workspace-switch.sh` 开头的注释里。

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
