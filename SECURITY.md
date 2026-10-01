# Security Policy / 安全政策

## Reporting a vulnerability / 报告漏洞

Please **do not open a public issue** for a security problem. Use GitHub's private reporting instead:
**Security tab, then "Report a vulnerability"** on this repository.

请**不要**为安全问题公开提 issue。请使用 GitHub 的私密报告：在本仓库的 **Security 标签页点击 "Report a vulnerability"**。

## What counts as a security problem / 哪些算安全问题

This tool creates symlinks and moves files inside your home directory, so these matter most:

- a way to **lose, overwrite or delete** a user file that the README says is safe;
- a way to write **outside** the documented locations (`links.txt` targets, `~/.cli-workbench-backup/`, `~/.cache/zsh/`);
- a default config that **exposes secrets** (for example saving terminal output or tokens to disk);
- committed credentials or personal data.

本工具会在你的家目录里创建软链接、移动文件，因此最重要的是：能让用户文件被**丢失、覆盖或删除**（而 README 说是安全的）、能写到**文档之外**的位置、默认配置**泄露密钥**、仓库中误提交了凭据或个人信息。

## Scope and expectations / 范围与预期

- Supported: the latest commit on `main`.
- This is a personal open-source project maintained on a best-effort basis; there is no guaranteed response time.
- Before applying anything on a machine you care about, run `scripts/link` without `--apply` (a dry run) and read the plan.

- 支持范围：`main` 分支的最新提交。
- 这是个人维护的开源项目，尽力而为，不承诺响应时间。
- 在你在意的机器上应用任何东西之前，先不加 `--apply` 运行 `scripts/link`（演练）并阅读计划。
