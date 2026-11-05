# Unity Dev Notes

BNU 实验室的 Unity 开发知识库（Knowledge Vault）。用「笔记 + 契约」的方式沉淀设计决策、冷门 bug、知识点和操作步骤，供人和 AI 智能体（DSH 插件）共同读写，避免重复踩坑、重复劳动。

## 目录结构

- `docs/` — 设计架构文档 + 机器可读契约（contracts），是「人 + AI」共同遵守的规范
- `notes/` — Unity 开发笔记本体（知识库），按类别（category）分目录
- `docs/templates/` — 笔记模板（bug / knowledge / how-to / snippet）
- `tools/vault.ps1` — git 自动化（sync / index / validate / post）
- `skills/` — 给 DSH / agent 的技能（`posting-vault-notes`），分发来源

## 学生入口

- 查报错：双击 `search-notes.cmd`，或让 DSH“查这段报错，显示适用环境与验证情况”。
- 环境检查：双击 `check-environment.cmd`；首次配置运行 `tools/setup.ps1 -UserName <署名> -Email <隐私邮箱>`。
- 详细步骤和网页备用入口见 [新同学上手](docs/onboarding.md)。本地搜索不需要上传授权。

## 快速开始：用 DSH 生成一篇笔记

> 用中文、精简。参考 `docs/templates/how-to.md` 模板，根据这个 reference（附链接）生成一篇 how-to 笔记：「如何安装 Unity CLI」。Summary 放在顶部，AI 可复用的 prompt 放在底部，frontmatter 的 `status` 设为 `draft`。

DSH 会按模板产出草稿（`status: draft`），你提交 PR 审核后合并为 `formalized`。

## 如何贡献（人工审核流程）

1. 新建分支 `note/<id>`（或让 DSH 直接在草稿分支上写）。
2. 按对应模板写 `notes/<category>/<YYYY-MM-DD>-<slug>.md`。
3. `status` 设为 `draft`，提交 PR，标题形如 `note: 安装 Unity CLI`。
4. 按 [docs/note-spec.md](docs/note-spec.md) 的 checklist 审核，通过后把 `status` 改为 `formalized` 再合并。

## 自动化工具（P0）

仓库自带 [tools/vault.ps1](tools/vault.ps1)，把「同步 → 分支 → 写笔记 → 重建索引 → 提交 → push → 创建或复用 PR」合成一条命令，解决「忘了 pull / 直推 main / 索引滞后」：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 post -File <草稿.md>
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 sync
```

用 DSH 发笔记：先按 `docs/templates/` 生成草稿，再 `post` 发布（自动开 `note/<id>` 分支 + 重建 `notes/index.json` + push + 创建真实 PR，显示待审核状态）。完整用法见技能 `posting-vault-notes`。

## 规范入口

- 新同学上手（5 分钟，非技术向）→ [docs/onboarding.md](docs/onboarding.md)
- 管理员手册 → [docs/admin.md](docs/admin.md)
- 总架构与设计决策 → [docs/architecture.md](docs/architecture.md)
- 笔记格式与 frontmatter 契约（人读版）→ [docs/note-spec.md](docs/note-spec.md)
- 未来智能体 / DSH 插件集成设计 → [docs/agent-integration.md](docs/agent-integration.md)
- 机器可读契约 → [docs/contracts/note.schema.json](docs/contracts/note.schema.json)

## 检索、修订与反馈

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 search -Query "ECONNREFUSED localhost" -IncludeDrafts
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 search -File error.txt -UnityVersion 2022.3 -Json
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 post -Update -File <修订稿.md>
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 feedback -NoteId <id> -Message <问题和环境> -DryRun
```

搜索为本地关键词匹配；默认排除草稿和废弃笔记，`-IncludeDrafts` 加入草稿但仍排除废弃笔记。Unity 版本筛选保留未注明版本的结果，并将其环境标为未知，不代表已验证兼容。

自动 PR 和反馈 issue 目前支持 `github.com` 源仓库，使用本机 Git 凭据，不另需 GitHub CLI。其他托管服务可用本地草稿与搜索，但需另行接入其审核 API。`-NoPush` 只在本地提交，不创建 PR；`-DryRun` 不提交、不上传。

维护者离线测试：`python tests/test_vault.py`（需要 Python，仅用于测试；使用隔离的本地 Git 仓库和 API 替身，不发布测试内容）。
