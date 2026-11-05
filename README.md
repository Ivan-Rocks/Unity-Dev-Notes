# Unity Dev Notes

BNU 实验室的 Unity 开发知识库（Knowledge Vault）。用「笔记 + 契约」的方式沉淀设计决策、冷门 bug、知识点和操作步骤，供人和 AI 智能体（DSH 插件）共同读写，避免重复踩坑、重复劳动。

## 目录结构

- `docs/` — 设计架构文档 + 机器可读契约（contracts），是「人 + AI」共同遵守的规范
- `notes/` — Unity 开发笔记本体（知识库），按类别（category）分目录
- `docs/templates/` — 笔记模板（bug / knowledge / how-to / snippet）

## 快速开始：用 DSH 生成一篇笔记

> 用中文、精简。参考 `docs/templates/how-to.md` 模板，根据这个 reference（附链接）生成一篇 how-to 笔记：「如何安装 Unity CLI」。Summary 放在顶部，AI 可复用的 prompt 放在底部，frontmatter 的 `status` 设为 `draft`。

DSH 会按模板产出草稿（`status: draft`），你提交 PR 审核后合并为 `formalized`。

## 如何贡献（人工审核流程）

1. 新建分支 `note/<id>`（或让 DSH 直接在草稿分支上写）。
2. 按对应模板写 `notes/<category>/<YYYY-MM-DD>-<slug>.md`。
3. `status` 设为 `draft`，提交 PR，标题形如 `note: 安装 Unity CLI`。
4. 按 [docs/note-spec.md](docs/note-spec.md) 的 checklist 审核，通过后把 `status` 改为 `formalized` 再合并。

## 规范入口

- 总架构与设计决策 → [docs/architecture.md](docs/architecture.md)
- 笔记格式与 frontmatter 契约（人读版）→ [docs/note-spec.md](docs/note-spec.md)
- 未来智能体 / DSH 插件集成设计 → [docs/agent-integration.md](docs/agent-integration.md)
- 机器可读契约 → [docs/contracts/note.schema.json](docs/contracts/note.schema.json)
