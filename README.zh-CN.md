# cli-workbench

[English](README.md) | 简体中文

把你的命令行环境（zsh、tmux、Ghostty、Git、Claude Code 状态栏）放进**同一个 Git 仓库**，并通过软链接让本机实际使用的文件**就是**仓库里的文件。几个小而经过测试的 shell 脚本负责安全地规划、应用、检查和诊断这些链接。

> **它是什么：** 一个自带合理默认配置的个人 dotfiles 框架。你 fork 或克隆它，修改 `config/`，把它变成你自己的。
> **它不是什么：** 不是包管理器、不是一键安装器、也不是主题包。它不会安装软件，也不管理密钥。

## 使用条件与适用范围

| | |
|---|---|
| **平台** | **macOS** 是主要平台（在 macOS 15、Apple Silicon 上测试）。脚本以及 zsh、tmux 配置在 **Ubuntu 24.04** 上也通过了完整测试和首次使用流程（在容器中验证）；Ghostty 配置和 Homebrew 的 cask 是面向 macOS 的。不支持 Windows。 |
| **Shell** | zsh 5.8 及以上（在 5.9 上测试）。脚本兼容 bash 3.2，也就是 macOS 自带的 bash 就够用。 |
| **tmux** | 建议 3.2 及以上（在 3.5a 上测试）。更旧的版本仍能加载配置，只是少了工作台切换键。 |
| **必需** | `git`；如果使用 zsh 组件，还需要 `zsh`（没有它时 `doctor` 会报 FAIL） |
| **可选** | `fzf`（0.48+ 才有 shell 集成）、`zoxide`、`starship`、`jq`（状态栏用）、[Ghostty](https://ghostty.org) 加一款 Nerd Font、Homebrew |

**它会在你的机器上做的改动，仅此而已：**

- [`links.txt`](links.txt) 中列出的软链接，并且只有你运行 `scripts/link <组件> --apply` 时才创建；
- 被这些链接替换的文件的备份，放在 `~/.cli-workbench-backup/<时间戳>/`，附带一份 `RESTORE` 说明；
- 使用自带 `zshrc` 后，在 `~/.cache/zsh/` 里生成 zsh 补全缓存。

**它绝不会：** 删除你的文件、安装软件、不加 `--apply` 就改动任何东西，也不会碰 `links.txt` 之外的文件。

## 快速开始

```sh
git clone <你的 fork 或本仓库地址> ~/dev/cli-workbench      # 放在哪里都可以
cd ~/dev/cli-workbench

scripts/bootstrap                  # 只读：检查，并给出将要链接什么的计划
scripts/link tmux --apply          # 一次只应用一个组件，然后只验证这一个
scripts/check tmux
```

组件（来自 `links.txt`）：

| 组件 | 目标 | 说明 |
|---|---|---|
| `tmux`、`tmux-scripts` | `~/.tmux.conf`、`~/.tmux/scripts` | 前缀键 `Ctrl-a`、vi 键位、鼠标、工作台切换器 |
| `zsh` | `~/.zshrc` | 会替换你现有的 `.zshrc`（先备份，不会删除）；请先把你自己的改动移到 `local.zsh` |
| `zsh-autostart` | `~/.config/zsh/tmux-autostart.zsh` | 新标签页的 tmux 会话选择器，可选，默认关闭 |
| `ghostty` | `~/.config/ghostty/config` | Catppuccin Mocha 主题、Nerd Font、macOS 标签式标题栏 |
| `claude-statusline` | `~/.claude/statusline.sh` | 仅在使用 Claude Code 时需要 |

Git：可移植的那部分设置没有做成链接，因为各种工具会写 `~/.gitconfig`。请改用 include：

```sh
git config --global --add include.path "$PWD/config/git/config"
```

推荐的应用顺序和需要手动完成的步骤（用 Homebrew 装工具、tmux 插件管理器）见 [`docs/bootstrap.md`](docs/bootstrap.md)。

## 你可能想先改的默认值

这些是个人偏好，不是硬性要求。直接改 `config/` 里的文件即可；因为是软链接，改动立刻生效。

- **tmux：** 前缀键是 `Ctrl-a`（不是 `Ctrl-b`）；复制模式用 vi 键位；开启鼠标；窗口从 1 开始编号。窗格内容**默认不会**保存到磁盘（那会把窗格里打印过的任何东西，包括令牌，明文存盘）；想开启的话看 `@resurrect-capture-pane-contents` 旁边的注释。
- **zsh：** 5 万行的共享历史、补全不区分大小写、`starship`、`zoxide`、`fzf` 仅在已安装时启用。
- **Ghostty：** Catppuccin Mocha 主题和 `SauceCodePro Nerd Font Mono` 字体（请安装该字体，或改掉这一行）。

## 改成你自己的

- **每台机器不同的设置**（额外的 PATH、代理、是否开启 tmux 选择器）：把 `templates/local.zsh.example` 复制为 `~/.config/zsh/local.zsh`。它不入库，并且最后加载。
- **密钥：** 把 `templates/secrets.zsh.example` 复制为 `~/.config/zsh/secrets.zsh`，权限 600，绝不提交。仓库里永远不能出现密钥或令牌。
- **增加另一个工具：** 把它的配置放进 `config/<工具>/`，在 `links.txt` 加一行（`组件名  仓库内路径  ~/目标路径`），先运行 `scripts/link <组件>` 看计划，再加 `--apply`。
- **Neovim：** 不附带编辑器配置。请自己添加 `config/nvim`，并取消 `links.txt` 里 `nvim` 那一行的注释。

## 命令

```sh
scripts/check [组件 ...]  # 快速、只读：链接是否指向正确源文件、zsh 和 shell 脚本能否解析、状态栏测试
                         # （指定组件名就只检查它们的链接；tmux 配置由 doctor --deep 加载）
scripts/doctor           # 再加：工具、PATH 重复和失效项、代理变量、仓库状态
scripts/doctor --deep    # 再加：真正启动 zsh、tmux、nvim（zsh 运行的是你自己的启动文件；tmux 用私有 socket；nvim 用你的配置）
scripts/link [组件] [--apply] [--adopt]
tests/run.sh             # 脚本自身的测试，包括在临时家目录里把本 README 的快速开始完整跑一遍
```

输出为 `PASS` / `WARN` / `FAIL`。`check` 和 `doctor` 只在出现 `FAIL` 时返回非零。

## 安全机制

- 不加 `--apply`，`scripts/link` 只是**演练**。
- 已存在的普通文件会被**移走**而不是删除，放在 `~/.cli-workbench-backup/<时间戳>/`。
- 目标是真实目录，或是指向别处的软链接时，`link` 会**停下**，直到你看过计划并为该组件加上 `--adopt`。
- `--apply` 会**先检查所有选中的组件**：只要有任何一个会停下、或源文件缺失，就一个都不改。开始应用之后如果某一步失败，会报告出来，已经应用的组件保持不变。
- 备份之后如果链接创建失败，原文件会被**自动放回**；但如果这期间那个路径上出现了新的东西，就保留备份并打印它的位置。
- 目标如果位于本仓库内部（包括将要在仓库里创建的路径），或者包含了本仓库，**会被拒绝**，加 `--adopt` 也一样。例如 `~/.config` 软链接到了本仓库的 `config/`。
- `scripts/bootstrap`、`check`、`doctor` 不会修改你的文件，只可能在系统临时目录里创建并删除临时文件。
- `doctor --deep` 会真正启动程序：它运行**你自己的 zsh 启动文件**和**你的 nvim 配置与数据**，所以它们做的事（写文件、更新插件）都是真的；只有自带 `zshrc` 的缓存目录是一次性的。tmux 使用私有 socket。

## 工作台切换器（tmux）

按 `prefix` 再按 `P`（`Ctrl-a P`），弹出 `~/dev/projects` 的选择列表。根目录下的每一个直接子目录就是一个工作台，以一个 tmux session 打开，左边编辑器、右边 shell。如果某个目录自己不是仓库、里面却有多个仓库（多仓库产品），它就是**一个**工作台，每个仓库一个窗口。选择已存在的工作台只会切换过去。需要 tmux 3.2+ 和 `fzf`。

要扫描别的目录，取消 `config/tmux/tmux.conf` 里 `WORKSPACE_ROOTS` 那行的注释并修改。更多细节见 `config/tmux/scripts/workspace-switch.sh` 的文件头。

## 卸载与恢复

这些链接就是普通的软链接。要还原，删掉链接，再把备份移回原位；`~/.cli-workbench-backup/<时间戳>/RESTORE` 列出了每个被替换文件的原路径。

## 排错

- `FAIL link ...`：运行 `scripts/link <组件>` 看计划。出现 `STOP` 表示有真实目录或外部链接挡着：先对比，再 `--adopt`。
- tmux 配置有问题：`scripts/doctor --deep` 会在私有 socket 上加载它。
- 更多见 [`docs/architecture.md`](docs/architecture.md)。

## 参与贡献

欢迎提 issue 和 pull request。安全问题请看 [SECURITY.md](SECURITY.md)，不要公开提 issue。请保持脚本兼容 bash 3.2，新增行为要加测试，提交前运行 `tests/run.sh`。仓库里的 GitHub Actions 工作流（`.github/workflows/tests.yml`）会在每次 push 和 pull request 时，在 macOS 和 Ubuntu 上运行整套测试。请不要带入个人路径、姓名或任何凭据。

## 许可证

[MIT](LICENSE)
