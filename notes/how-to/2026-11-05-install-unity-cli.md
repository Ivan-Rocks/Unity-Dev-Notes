---
id: 2026-11-05-install-unity-cli
title: 安装 Unity CLI
category: how-to
status: formalized
tags: [unity-cli, install, setup, terminal]
created: 2026-11-05
updated: 2026-11-05
author: DSH
unity_version: "6000.3"
related: []
source:
  - title: Use the Unity command-line interface (CLI)
    url: https://docs.unity.com/en-us/unity-cli/use-unity-cli
    accessed: 2026-11-05
---

## Summary

Unity CLI 是 Unity 官方推出的独立命令行工具，可在不装 Unity Hub 的情况下从终端安装 Editor、增删模块、创建/打开项目，适合 CI 与自动化。Windows 用一条 PowerShell 命令安装，装完 `unity --version` 验证即可。

## 正文

### 兼容性

- Windows 10 21H1+ / macOS 14+ / Linux RHEL 9 或 Ubuntu 22.04+（需 glibc ≥ 2.34）

### 安装（推荐：官方脚本）

```powershell
# Windows（PowerShell）
irm https://unity.com/install.ps1 | iex
```

```bash
# macOS / Linux
curl -fsSL https://unity.com/install.sh | bash
```

验证：`unity --version`。若提示找不到命令，把安装目录加入 `PATH` 或重开终端。

### 其它安装方式（可选）

- winget（Windows）：`winget install Unity.CLI`
- Homebrew（macOS/Linux）：`brew install --cask unity-cli`
- Linux 包仓库（apt / dnf）：见官方文档配置仓库后 `apt install unity-cli` / `dnf install unity-cli`

### 常用命令速查

| 命令 | 作用 |
| --- | --- |
| `unity --help` | 顶层帮助 |
| `unity install lts` / `unity install 6000.3.7f1` | 安装 Editor（别名或具体版本） |
| `unity install-modules -e 6000.3.7f1 -m ios android` | 给已装 Editor 加模块 |
| `unity editors -i` | 列出已装 Editor |
| `unity open ./MyProject` | 打开项目 |
| `unity doctor` | 打印诊断快照 |
| `unity self-update` | 更新 CLI 到最新版 |

## AI Prompt

> 给 AI 的上下文与可复用指令，便于后续自动化 / 排障时快速定位。

- **执行指令模板**：「我在 {OS} 上要用命令行安装 Unity Editor {版本} 并添加 {模块} 模块，请给出完整可复制的命令，并说明如何验证安装成功。」
- **注意 1**：`unity projects create` 默认会创建 Unity Cloud 项目（需要登录）；本地项目加 `--no-cloud`，全本地流水线可设环境变量 `UNITY_NO_CLOUD`。
- **注意 2**：包管理器安装（Homebrew / apt / dnf）由包管理器负责更新，不要再用 `unity self-update`（会冲突）；winget 装的是 MSIX，`unity self-update` 仍可用。
- **AI 插件关联**：使用 Claude Code / Codex / Grok 等 agent 时，Unity 官方提供 plugin（含 `unity-cli` skill），skills 仓库见 https://github.com/Unity-Technologies/skills 。
