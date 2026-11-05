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
| `render_pipeline` | string | 可选 | Built-in / URP / HDRP 等适用管线，未知时省略 |
| `platform` / `device` | string | 可选 | 已验证的系统、平台或设备 |
| `prerequisites` | string | 可选 | 依赖插件、版本及其他适用前提 |
| `verification` | string | 可选 | `unverified` / `reproduced` / `verified`，分别表示未验证、已复现、已验证解决 |
| `diagnosis` | string | 可选 | `unknown` / `suspected` / `confirmed`，分别表示根因未知、推测、已确认 |
| `resolution` | string | 可选 | `unresolved` / `workaround` / `fixed`，分别表示未解决、临时绕过、已修复 |
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
仅保留给 AI 的可复用操作提示；适用条件、诊断步骤、验证方式放在正文供人阅读。
```

**各 category 的正文小节**：

- `bugs`：`## Summary` → `## 现象` → `## 原因` → `## 解决` → `## AI Prompt`
- `knowledge`：`## Summary` → `## 要点` → `## AI Prompt`
- `how-to`：`## Summary` → `## 正文`（步骤）→ `## AI Prompt`
- `snippet`：`## Summary` → `## 代码` → `## AI Prompt`

## 4. 精简原则

1. **Summary 是硬要求**，任何人/索引扫一眼就知道这篇讲什么。
2. 正文只留「执行路径」，删掉背景铺垫、过程性废话。
3. 正文保留学生排错需要的**适用条件、诊断步骤、验证方式**。长日志放附件或单独链接；`AI Prompt` 仅放 agent 的操作提示。
4. 正文优先精简，但不要为满足一屏限制删掉复现条件或验证证据；必要时拆成关联笔记。

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

## 7. 不确定原因、适用范围与纠错

- 根因未知时允许直接写“原因待确认”，设置 `diagnosis: unknown`；猜测写 `suspected` 并列出待验证项。不要把猜测写成已确认原因。
- 只有临时绕过方法时设置 `resolution: workaround`，正文说明局限；不能把“能运行一次”当成完整修复。
- `status` 是审核状态，`verification` 是技术验证程度。`formalized` 不等于对所有版本验证有效；字段缺失表示未知。
- 每篇可在正文增加 `## 适用条件`、`## 验证方式`。搜索会同时展示已有环境字段和验证程度；字段缺失不会自动补成“已验证”。
- 补充已有笔记：保留 `id`、`category`、`created`，更新 `updated`，将 `status` 设为 `draft`，确认后执行 `post -Update -File <修订稿.md>`。它创建新的审核分支，不直接修改 main。
- 反馈失效：先展示将发送的内容，确认后执行 `feedback -NoteId <id> -Message <现象、环境和预期>`；它创建 issue，管理员判断后再修改，不自动废弃笔记。

元数据使用简单 YAML：根字段为单行字符串；`tags`、`related` 支持行内列表或缩进短列表；`source` 用模板中的对象列表。内置 PowerShell 校验器只检查必填值、id、日期、枚举和文件名，不是完整 YAML/JSON Schema 实现。正式契约以 Schema 为准。
