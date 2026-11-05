# 智能体 / DSH 插件集成设计（未来）

> 本文档是**方向性设计**，不是现在要实现的内容。写清楚「未来插件怎么把本库当知识库用、怎么往里写、怎么维护」，确保现在定的契约足够支撑，届时不必重构。

## 1. 目标

未来实验室会做一条「课件 → Unity 插件」的智能体链路。DSH 插件（或其它 agent）需要把本 repo 当作**可信知识库**：

- 遇到冷门 bug，AI 一看描述就能定位到已有笔记，给出方案，避免重复劳动。
- 同学解决了一个新 bug，agent 能主动提议「是否创建 note」，草稿生成后走人工审核。
- agent 能对存量笔记提出维护意见（过时、重复、缺来源）。

## 2. 三个接入面

| 接入面 | 动作 | 产物/副作用 |
| --- | --- | --- |
| **读（检索）** | 加载 `notes/index.json` → 命中 → 读全文 `.md` | 只读，无副作用 |
| **写（生成）** | 按模板生成 `status: draft` 笔记，开 `note/<id>` 分支 | 新草稿 + PR |
| **维护（formalize/建议）** | 扫描存量，产出建议（不改 formalized 正文） | PR 或 issue 形式的建议 |

**安全边界**：agent 只允许创建 `draft` / 在 `draft` 分支上写；把 `status` 改为 `formalized` 并合并是**人工动作**，插件不自动执行（除非未来有显式授权）。

## 3. 契约（Contracts）

智能体只依赖三份稳定契约，不看 docs 里的叙述文字：

1. **[contracts/note.schema.json](contracts/note.schema.json)** — frontmatter 结构与枚举（category/status）。
2. **`notes/index.json`** — 所有笔记的元数据索引（id/path/title/category/status/tags/updated/summary）。检索先打索引，避免全库遍历。
3. **taxonomy**（category 枚举 + status 枚举）— 由 schema 承载，即上面两处。

`index.json` 的结构约定：

```json
{
  "generated": "2026-11-05",
  "notes": [
    {
      "id": "2026-11-05-install-unity-cli",
      "path": "how-to/2026-11-05-install-unity-cli.md",
      "title": "安装 Unity CLI",
      "category": "how-to",
      "status": "formalized",
      "tags": ["unity-cli", "install"],
      "updated": "2026-11-05",
      "summary": "……"
    }
  ]
}
```

**维护方式**：`index.json` 由仓库脚本 `tools/vault.ps1 index`（或 `post` 内部调用）从各 `.md` 自动生成，不手写。生成规则：`path` = 相对 `notes/` 的路径，`summary` 取正文 `## Summary` 的首段（Summary 只在正文存在，frontmatter 不冗余存，避免两处漂移）。遇到冲突「regenerate，不 merge」——整份重建，不手动解决 index 冲突。

## 4. 检索策略（读）

1. 先把用户/AI 的查询转成关键词，在 `index.json` 的 `title` + `tags` + `summary` 上做轻量匹配。
2. 按 `status == formalized` 过滤（可信内容优先），`deprecated` 排除。
3. 命中后读对应 `.md` 全文，把 `## AI Prompt` 一并喂给下游 agent 作为可复用上下文。
4. 未命中 → 进入「建议创建 note」流程（§6）。

> 轻量关键词 + index 先行，是为了在笔记量还小的时候不依赖向量库/RAG 基建。等笔记量大到几千篇，再在 index 之上加 embedding 检索，契约不变。

## 5. 冷门 bug 场景（读的典型用例）

用户给 AI 一段报错描述 → AI 检索 index → 命中「同类 bug」笔记 → 直接复述 `现象/原因/解决`，并把 `AI Prompt` 作为上下文继续追问。**价值点**：一个人解决过的冷门 bug，全员可复用，不用再从头排查。

## 6. 建议创建 note（写的典型用例）

1. 同学解决了一个新 bug，agent 判定「库中无同类记录」。
2. agent 主动提示：「要不要创建一篇 bug 笔记？我可以按模板起草。」
3. 用户同意 → agent 按 `docs/templates/bug.md` 生成 `status: draft`，开 `note/<id>` 分支。
4. 走人工 PR 审核（§7），通过后 `formalized` 合入，index 重建。

## 7. PR / 人工审核设计

- **分支**：`note/<id>`（写笔记）、`docs/<改动>`（改契约）。
- **状态驱动**：PR 内笔记 `status: review`；审核通过 → `formalized` → 合并。
- **审核人**：冷门 bug 类建议 2 人 approve；普通知识/how-to 1 人即可。
- **自动化辅助**：CI 用 `note.schema.json` 校验 frontmatter；重复检测用 `index.json` 标题/标签比对给出提示（不阻断）。
- **权限**：agent 用专用 token，只给「开分支 + 提交 PR」权限，不给「直接 push main / 合并」权限。

## 8. 与 Unity 官方 agent 生态的关系

Unity 已提供面向 AI agent 的官方 plugin 与 skills 仓库：

- 官方 plugin（含 `unity-cli` skill 等）针对 Claude Code / Codex / Grok。
- skills 仓库：https://github.com/Unity-Technologies/skills

**定位**：Unity 的 skills 解决「怎么操作 Unity」，本库解决「我们实验室踩过的坑/知识」。二者互补：未来 DSH 插件可复用 Unity 的 `unity-cli` skill 执行命令，再把结果/教训按本库契约沉淀成 note。设计契约时保持 Markdown + frontmatter 通用格式，就是为了能和这类生态对接。

## 9. Roadmap（非现在实现，仅记录顺序）

1. **P0**：跑通「DSH 生成草稿 → 人工 PR → formalized」——已落地 `tools/vault.ps1`（sync / index / validate / post / cleanup）+ 技能 `posting-vault-notes`。
2. **P1**：CI 校验 frontmatter（用 `note.schema.json`）仍待接入；`post` 现已用 GitHub REST API 自动创建/复用真实 PR，不依赖 `gh`，失败可用 `pr` 重试。
3. **P2**：本地 `vault.ps1 search` 已支持报错/关键词检索并显示适用环境；DSH 插件的自动检索与全文回填仍待接入。
4. **P3**：DSH 插件实现「写」——bug 解决后主动提议建 note，开分支 + PR。
5. **P4**：维护助手——定期扫描重复/过时/缺来源，产出建议 PR。
6. **P5**：接入「课件 → Unity 插件」链路，把本库作为插件的上下文知识库。
