# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for a security problem. Use GitHub's private reporting instead:
**Security tab, then "Report a vulnerability"** on this repository.

## What counts as a security problem

This tool creates symlinks and moves files inside your home directory, so these matter most:

- a way to **lose, overwrite or delete** a user file that the README says is safe;
- a way to write **outside** the documented locations (`links.txt` targets, `~/.cli-workbench-backup/`, `~/.cache/zsh/`);
- a default config that **exposes secrets** (for example saving terminal output or tokens to disk);
- committed credentials or personal data.

## Scope and expectations

- Supported: the latest commit on `main`.
- This is a personal open-source project maintained on a best-effort basis; there is no guaranteed response time.
- Before applying anything on a machine you care about, run `scripts/link` without `--apply` (a dry run) and read the plan.
