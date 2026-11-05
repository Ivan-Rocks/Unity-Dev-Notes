# 新同学上手：先查经验，再决定是否发笔记

## 只想查报错

双击仓库里的 **search-notes.cmd**，粘贴一行报错或关键词。也可以在 DSH 里说：

> 帮我查这段报错有没有相关笔记，同时告诉我适用的 Unity 版本、管线和验证情况。

无需配置 Git 提交者或授权上传即可本地搜索。默认只显示已审核笔记，草稿需要主动加入搜索；没有命中时尝试更少的关键词。

## 准备贡献笔记：一次性设置

1. 安装 [Git](https://git-scm.com/downloads)，然后将仓库克隆到你选择的位置；已经有本地仓库则跳过下载。
2. 在仓库目录运行一次：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup.ps1 -UserName "你的署名" -Email "你的 GitHub 隐私邮箱"
```

设置只作用于当前仓库；技能会安装到本机 agent 技能目录，自动写入当前仓库路径，不要求安装在用户主目录。重新打开 AI 会话后生效。已有技能如有变化会先备份。

3. 双击 **check-environment.cmd** 查看本地环境；准备上传时再运行联网检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 doctor -Online
```

联网检查会核对本机 Git 登录账号及仓库写入权限。若需要登录，使用 Git Credential Manager 完成浏览器授权；不要把令牌写进笔记。浏览器登录与本机 Git 登录是两回事。

GitHub 网络不通时，本地搜索和草稿仍然可用；离线检查通过不代表无代理网络或上传权限已经验证。

## 发一篇笔记

对 DSH 说出经历，例如“这个报错原因还没确认，但重启后暂时恢复了，帮我先记下来”。AI 应先查重、展示草稿，再让你选择“发 / 改 / 不发”。原因未知可以如实保留。

确认后执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 post -File <草稿.md>
```

成功会显示 **PENDING_REVIEW** 和真实 `/pull/数字` 链接，表示等待管理员审核，不代表已经进入主库。

如果显示 **PR_PENDING**，说明审核请求尚未完成。留在当前分支重试下面命令，不要重新发同一篇笔记：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 pr
```

## 纠错与失效反馈

- 能改正文：让 AI 读取原笔记，保留原 id、category、created，生成 `draft` 修订稿，确认后用 `post -Update -File <修订稿.md>`。
- 只知道不适用：说明笔记 id、环境、报错及预期；确认内容后用 `feedback -NoteId <id> -Message <反馈>` 创建反馈 issue。先加 `-DryRun` 可预览而不发送。

## 无法运行工具时的备用入口

打开 [GitHub 笔记目录](https://github.com/Ivan-Rocks/Unity-Dev-Notes/tree/main/notes)，在对应类别中按模板添加文件，或打开已有文件编辑。提交时选择**新建分支并创建 Pull Request**，不要直接提交到 main。也可在 [Issues](https://github.com/Ivan-Rocks/Unity-Dev-Notes/issues) 反馈，并附上相关笔记链接。

DSH 的受限 Windows 命令环境可能在脚本启动前失败。此时环境限制不能写成“校验通过”；可由本人在本机 PowerShell 运行同一校验，或使用上述网页入口，不必关闭系统保护。
