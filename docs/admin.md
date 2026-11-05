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

## 分支清理

学生每发一篇笔记会开一个 `note/<id>` 分支；合并后分支不自动删，会越堆越多（学生大概率不会自己清理 git）。

- **远程分支**：GitHub 仓库 → **Settings → General → 勾选 "Automatically delete head branches"**。合并 PR 后远程分支自动删除。
- **本地分支**：跑 `tools/vault.ps1 cleanup`，删掉所有「已合并进 origin/main」的 `note/*` 本地分支，保留未合并的。建议让学生发笔记前顺手跑一次（或让 DSH 在 post 前自动清）。

## 交接清单

- [ ] GitHub 加 collaborator（Write）
- [ ] 发 onboarding 链接
- [ ] 确认对方 clone + 认证 +（用 agent 才装技能）
- [ ] 确认对方能 push 出 `note/<id>` 分支

## 发布状态与技术验证分开审核

- `post` 使用 Git Credential Manager 的本机凭据创建或复用真正的 PR，只有返回 `PENDING_REVIEW` 与 `/pull/<number>` 链接才算提交审核成功。
- `PR_PENDING` 表示未完成审核请求；上传分支后可在原分支运行 `vault.ps1 pr` 重试，避免重复发布同 id。
- 新增可选环境与证据字段，旧笔记无需立即迁移；缺失按未知处理。索引新增同名可选字段，旧消费者应忽略未知字段；不要把缺失字段推断为 verified。
- 对 `diagnosis: unknown` 的现场记录和 `resolution: workaround` 的临时方案仍可审核入库，但需保留限制。`status: formalized` 只表示审核通过，不扩大适用范围。
- 修订笔记使用 `post -Update`，保留 id/category/created，状态回到 draft；失效反馈创建 issue，由管理员判断，不自动标 deprecated。
- 管理员修改状态后需再次运行 `vault.ps1 index`，使索引与实际文件一致。搜索读取笔记本体，可避免旧索引漏掉最新修订，但其他索引消费者仍需重建。
- 默认诊断不发送网络请求；`doctor -Online` 会读取 GitHub 账号和仓库权限。凭据仅在内存中使用，不应出现在输出、仓库或日志中。
