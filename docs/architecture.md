# Unity Dev Notes — 架构设计

> 本文档定义这个 Knowledge Vault 的「是什么、为什么、怎么组织、怎么协作」，是人与 AI 智能体共同遵守的规范。给自动化用的机器可读契约在 [contracts/note.schema.json](contracts/note.schema.json)，未来插件/智能体接入设计在 [agent-integration.md](agent-integration.md)。

## 1. 目的与背景

实验室同事在 Unity 开发中会反复遇到三类问题：

1. **重复劳动**：冷门 bug 有人已经踩过、解决了，但知识没沉淀，下一个人又从头排查一遍。
2. **知识散落**：解决方案散在聊天记录、口头交流、个人记忆里，无法检索、无法复用。
3. **自动化缺乏载体**：后续要做的「课件 → Unity 插件」智能体链路，需要一个结构化、可被 AI 稳定读取的知识库作为上下文。

因此建这个 Vault：**把「人类可读的笔记」和「机器可读的契约」放在同一个 git repo 里**，让 DSH 既能生成、维护笔记，未来的智能体插件也能把它当作可靠的知识库。

## 2. 设计目标 / 非目标 / 反目标

**目标（Goals）**

- G1 笔记**精简**：每篇必须有 Summary，细节/建议下沉到「AI Prompt」区块，提升可读性。
- G2 **分门别类**：目录即类别，frontmatter 提供稳定的机器可读元数据。
- G3 **DSH 可生成**：prompt + 模板 → 草稿笔记，流程标准化。
- G4 **人工审核**：笔记从草稿到正式必须过 PR 审批（质量闸门）。
- G5 **可被智能体消费**：契约（schema + index + taxonomy）稳定，插件可做检索、生成、维护。

**非目标（Non-goals，现在不做）**

- 不实现自动「读课件 → 生成 Unity 插件」的完整链路（只预留设计）。
- 不做笔记的自动同步/发布到外部系统。
- 不引入重型 Wiki/知识库平台（Obsidian、Notion 等），保持纯 git + Markdown。

**反目标（Anti-goals）**

- 不要让笔记变成「什么都写、没人维护」的垃圾堆——宁缺毋滥，每篇都要过审核。
- 不要为了自动化牺牲可读性——人也要能直接读得舒服。
- 不要让契约随意变动——变更是 breaking change，要评审。

## 3. 目录结构

```
Unity-Dev-Notes/
├── README.md                     # Vault 总览 + 快速开始 + 贡献流程
├── .gitignore
├── docs/                         # 设计文档 + 契约（规范层）
│   ├── README.md                 # docs 索引
│   ├── architecture.md           # 本文档
│   ├── note-spec.md              # 笔记格式 + frontmatter 契约（人读版）
│   ├── agent-integration.md      # 未来插件/智能体接入设计
│   ├── contracts/
│   │   └── note.schema.json      # frontmatter JSON Schema（机器可读契约）
│   └── templates/                # 笔记模板
│       ├── bug.md
│       ├── knowledge.md
│       ├── how-to.md
│       └── snippet.md
└── notes/                        # 笔记本体（知识库）
    ├── README.md                 # notes 索引 + 类别说明
    ├── index.json                # 机器可读索引（供智能体检索）
    ├── bugs/                     # category = bugs
    ├── knowledge/                # category = knowledge
    ├── how-to/                   # category = how-to
    └── snippets/                 # category = snippet
```

**分层原则**：`docs/` 是「规范与设计」，`notes/` 是「内容」。智能体读写时只认 `notes/` + 两份契约文件（schema、index），不必理解 docs 里的叙述性文字。

## 4. 笔记格式（详见 note-spec.md）

每篇笔记 = **frontmatter（元数据）** + **正文**。核心要求：

- frontmatter 提供 `id / title / category / status / tags / created / updated / source` 等机器可读字段。
- 正文固定三段式：`## Summary`（精简摘要）→ `## 正文`（精简要点/步骤）→ `## AI Prompt`（给 AI 的细节、可复用 prompt、上下文）。

这样设计的原因：**Summary 供人和索引快速扫读，正文只保留可执行要点，真正长的细节/建议全部沉到 `## AI Prompt`，不打断正文阅读。**

## 5. 分类学（Taxonomy）

**category（主分类，目录即分类）**：`bugs` | `knowledge` | `how-to` | `snippet`（见 [notes/README.md](../notes/README.md)）。

**tags（交叉分类，自由但建议收敛）**：如 `install`、`build`、`shader`、`addressables`、`git`。标签用于跨类检索，不强制枚举，但鼓励复用已有标签。

**status（状态机）**：

```
draft ──(提交 PR)──> review ──(审核通过、合并)──> formalized
  │                                              │
  └────────────────(放弃)                         └──(过期/被取代)──> deprecated
```

- `draft`：草稿，刚由 DSH 生成或人初写，未审核。
- `review`：已开 PR，等待人工审核。
- `formalized`：审核通过并合入主干，是唯一「可信」状态。
- `deprecated`：内容过期或被新笔记取代，保留但标记，不删除（保留历史与引用）。

## 6. 笔记生命周期

1. **触发**：遇到 bug / 新知识 / 需要记录的流程；或智能体发现「这个 bug 库里有/没有记录」。
2. **生成**：DSH 按模板产出 `status: draft` 的笔记（见 §7）。
3. **审核**：开 PR → `status: review` → 人工按 checklist 审核（见 note-spec.md）。
4. **formalize**：通过后 `status: formalized`，合并入主干。
5. **维护**：DSH 定期或按需提出意见（更新步骤、补充来源、发现重复可合并、标记 deprecated）。

## 7. 工作流：DSH 生成 → 人工 PR 审批

**生成**：给 DSH 的 prompt 约定如下（可存为快捷指令）：

> 用中文、精简。按 `docs/templates/<category>.md` 模板，根据以下 reference（附链接）生成一篇 `<category>` 笔记，主题是「…」。Summary 放顶部，AI 可复用的 prompt 放底部，frontmatter 的 `status` 设为 `draft`。

**审批**：人工打开 PR，检查：
1. frontmatter 字段齐全、category 正确、source 带链接与访问日期。
2. Summary 是否真「精简」、正文是否可执行、AI Prompt 是否真正可用。
3. 是否与已有笔记重复（先查 `notes/index.json`）。

通过后改 `status: formalized` 再合并。**PR 是质量闸门，不是走过场。**

## 8. 未来智能体 / DSH 插件集成

方向性设计（实现见 [agent-integration.md](agent-integration.md)）：

- **读**：插件加载 `notes/index.json` 做快速检索，命中后再读对应 `.md` 全文。冷门 bug 描述 → 检索 → 命中即给方案。
- **写**：同学解决 bug 后，agent 提议「是否创建 note」，生成 `draft`，走人工 PR。
- **维护**：agent 定期扫描，提示重复、过时、缺来源的笔记，产出建议（不自动改 formalized 内容）。

关键发现：Unity 官方已提供面向 AI agent（Claude Code / Codex / Grok）的 plugin 与 skills 仓库（https://github.com/Unity-Technologies/skills），其中含 `unity-cli` skill。本库的契约设计应与这类生态兼容，而不是另起炉灶。

## 9. 治理约定

- **分支**：笔记用 `note/<id>` 短分支，PR 合并后删除。
- **提交信息**：`note: <title>` / `docs: <改动>`。
- **谁能合并**：实验室至少一名维护者审核后合并（建议 1 人 approve 即可，冷门 bug 类建议 2 人）。
- **契约变更**：`note.schema.json`、`category` 枚举、`status` 枚举、index 格式的改动视为 breaking change，需在 PR 描述里写明迁移方式。

## 10. 决策记录

| 决策 | 结论 | 来源 |
| --- | --- | --- |
| 笔记/文档语言 | 中文为主 + 英文术语 | 用户确认 |
| 审批流程 | DSH 起草 → 人工 PR 审批 | 用户确认 |
| 交付范围 | 架构 + 第一个 note + 脚手架 + 模板 | 用户确认 |
| 类别枚举 | bugs / knowledge / how-to / snippet | 我定的默认，可扩展 |
| 笔记结构 | Summary / 正文 / AI Prompt 三段式 | 用户要求 + 我的默认 |
| 契约形式 | JSON Schema + index.json | 我定的默认 |
| 目录分层 | docs 规范层 + notes 内容层 | 我定的默认 |

> 未标注「用户确认」的都是我的默认决策，读到这里若有异议请提出，改起来成本很低。
