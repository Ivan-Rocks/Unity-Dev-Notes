# 管理员手册

给维护这个 vault 的人。新同学看 [onboarding.md](onboarding.md)。

## 加新成员

1. GitHub 仓库 → **Settings → Collaborators → Add people**
2. 加对方 GitHub 账号，权限选 **Write**
3. 把 [onboarding.md](onboarding.md) 链接发给他，让他照做
4. 确认他完成一次性安装后，能 push 出一个 `note/<id>` 分支

## 审核笔记（PR）

同学 / DSH 发的笔记会开 `note/<id>` 分支 + PR。审核时按 [note-spec.md](note-spec.md) 的 checklist 过一遍：

- [ ] frontmatter 字段齐全、`category` 正确、`source` 带链接和访问日期
- [ ] `## Summary` 精简、正文可执行、`## AI Prompt` 可用
- [ ] 与已有笔记不重复（查 `notes/index.json`）
- [ ] `status` 已从 `draft` 改成 `formalized`

通过后合并到 `main`。`index.json` 在 post 时已被脚本重建，无需手动改。

## 技能维护

- 技能的**规范来源在仓库 `skills/posting-vault-notes/SKILL.md`**。
- 改了它之后，自己和每个成员的 `~/.agents/skills/posting-vault-notes/` 要同步更新（重新复制一份过去）。

## 契约 / 分类变更

`note.schema.json`、`category`/`status` 枚举、index 格式的改动是 breaking change：

1. 改 `docs/contracts/note.schema.json` + 对应模板
2. 同步更新 `tools/vault.ps1` 里的 `$Categories` / `$Statuses` 枚举
3. PR 描述里写明迁移方式

## 交接清单

- [ ] GitHub 加 collaborator（Write）
- [ ] 发 onboarding 链接
- [ ] 确认对方 clone + 认证 +（用 agent 才装技能）
- [ ] 确认对方能 push 出 `note/<id>` 分支
