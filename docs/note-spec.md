# 笔记格式规范（Note Spec）

本文档是笔记的「人读版契约」。机器可读版本见 [contracts/note.schema.json](contracts/note.schema.json)，二者必须保持一致；不一致时以 schema 为准。

## 1. 文件命名与 id

- 文件名：`<YYYY-MM-DD>-<slug>.md`，如 `2026-11-05-install-unity-cli.md`
- `slug`：英文小写 + 连字符，简短描述主题
- `id` = 文件名去掉 `.md`，是笔记的唯一标识，用于 `related` 引用和索引
- 同一篇笔记只能属于一个 category，因此它只放在一个目录下

## 2. Frontmatter 字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | 唯一标识，等于文件名去 `.md` |
| `title` | string | ✅ | 中文标题，一句话 |
| `category` | string | ✅ | `bugs` / `knowledge` / `how-to` / `snippet` |
| `status` | string | ✅ | `draft` / `review` / `formalized` / `deprecated` |
| `tags` | string[] | 建议 | 交叉分类，小写英文，如 `[install, git]` |
| `created` | date | ✅ | `YYYY-MM-DD` |
| `updated` | date | ✅ | `YYYY-MM-DD`，内容有实质改动时更新 |
| `author` | string | 建议 | 作者（人，或 `DSH`） |
| `unity_version` | string | 可选 | 涉及的 Unity 版本，如 `6000.3`、`2022.3` |
| `related` | string[] | 可选 | 相关笔记的 `id` 列表 |
| `source` | object[] | 建议 | 参考资料：`{ title, url, accessed }`，`accessed` 为访问日期 |

**source 示例**：

```yaml
source:
  - title: Use the Unity command-line interface (CLI)
    url: https://docs.unity.com/en-us/unity-cli/use-unity-cli
    accessed: 2026-11-05
```

## 3. 正文结构（三段式）

每篇笔记固定按以下顺序：

```markdown
## Summary
3–5 行精简摘要：是什么 / 怎么解决 / 适用场景。人和索引都先读它。

## 正文
精简要点或步骤（用 bullet、代码块）。只写可执行、可复用的内容。

## AI Prompt
给 AI 的细节、上下文、可复用 prompt 模板。长的、辅助性的内容全部放这里。
```

**各 category 的正文小节**：

- `bugs`：`## Summary` → `## 现象` → `## 原因` → `## 解决` → `## AI Prompt`
- `knowledge`：`## Summary` → `## 要点` → `## AI Prompt`
- `how-to`：`## Summary` → `## 正文`（步骤）→ `## AI Prompt`
- `snippet`：`## Summary` → `## 代码` → `## AI Prompt`

## 4. 精简原则

1. **Summary 是硬要求**，任何人/索引扫一眼就知道这篇讲什么。
2. 正文只留「执行路径」，删掉背景铺垫、过程性废话。
3. 真正的细节、排障分支、给 AI 的指令**全部下沉到 `## AI Prompt`**，不污染正文。
4. 一屏原则：正文部分尽量控制在一屏内（约 30 行），超出的拆成多篇或下放 AI Prompt。

## 5. 审核 Checklist（人工 PR 时逐项过）

- [ ] `id` 与文件名一致
- [ ] `category` 正确，且放在对应目录
- [ ] `status` 为 `draft`（合并前改 `formalized`）
- [ ] `source` 完整（有链接、有 `accessed`）
- [ ] Summary 精简且准确
- [ ] 正文可执行、可复用
- [ ] `## AI Prompt` 内容真实可用（不是空话）
- [ ] 与已有笔记不重复（先查 `notes/index.json`）
- [ ] frontmatter 通过 `note.schema.json` 校验

## 6. 与 schema 的关系

`note.schema.json` 只校验 frontmatter 的**结构与枚举**，不校验正文。自动化工具（DSH 插件、CI）用它做「元数据是否合法」的硬校验；「内容是否精简、AI Prompt 是否可用」属于人工审核的软校验，暂不机器化。
