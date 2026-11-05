# notes 索引

Unity 开发笔记本体。目录即类别（category）：一篇笔记只属于一个 category，用 `tags` 做交叉分类。

## 类别 (category)

| 目录 | category | 放什么 |
| --- | --- | --- |
| `bugs/` | `bugs` | 冷门 bug / 报错的复现、根因、解决方案 |
| `knowledge/` | `knowledge` | 概念、原理、机制等知识点 |
| `how-to/` | `how-to` | 安装、配置、操作步骤、流程 |
| `snippets/` | `snippet` | 可复用代码片段 |

> 类别可扩展：新增目录 + 在 [docs/contracts/note.schema.json](../docs/contracts/note.schema.json) 的 `category` enum 里加一项，并补一个模板。

## 文件命名

`<YYYY-MM-DD>-<slug>.md`，slug 用英文小写连字符，如 `2026-11-05-install-unity-cli.md`。`id` = 文件名去掉 `.md`。

## 状态 (status)

`draft`（草稿）→ `review`（待审，PR 中）→ `formalized`（已合入正式）→ `deprecated`（已废弃）。

## 已有笔记

| id | title | category | status |
| --- | --- | --- | --- |
| [2026-11-05-install-unity-cli](how-to/2026-11-05-install-unity-cli.md) | 安装 Unity CLI | how-to | formalized |

## 添加一篇笔记

1. 选模板：`docs/templates/<category>.md`
2. 填 frontmatter 与正文，`status: draft`
3. 按 [note-spec](../docs/note-spec.md) 检查，走 PR 审核
