# 新同学上手（只做一次，约 5 分钟）

> 这篇给「只想记笔记、不想碰代码」的同学。全程**复制粘贴**，遇到要填的地方换成你自己的名字/邮箱。

## 一次性安装

### ① 装 git（一句带过，不用学）

去 <https://git-scm.com> 下载，一路「下一步」装完。你只需要它存在，不需要会用。

### ② 打开 PowerShell

按键盘 `Win` 键 → 输入 `powershell` → 回车，会弹出一个黑色窗口。

### ③ 复制下面 4 行，一行一行粘贴回车

```powershell
git clone https://github.com/Ivan-Rocks/Unity-Dev-Notes.git "$env:USERPROFILE\Unity-Dev-Notes"

git config --global user.name "你的名字"
git config --global user.email "你的邮箱"

git config --global credential.helper manager

New-Item -ItemType Directory -Force "$env:USERPROFILE\.agents\skills\posting-vault-notes" | Out-Null; Copy-Item "$env:USERPROFILE\Unity-Dev-Notes\skills\posting-vault-notes\SKILL.md" "$env:USERPROFILE\.agents\skills\posting-vault-notes\SKILL.md" -Force
```

> - `"你的名字"` / `"你的邮箱"` 换成你自己的，例如 `"张三"`、`"zhangsan@163.com"`。
> - 如果第 1 行提示「目录已存在」，说明你之前装过，跳过这行继续往下。

### ④ 第一次发布时，授权一次

浏览器会自动弹出，登录你的 GitHub 账号，点「授权」。之后再也不用了。

✅ **装好了。以后不用再碰这些命令。**

## 以后就这样记笔记

打开 DSH，直接说人话，例如：

> 「帮我把这个 bug 记成笔记：Unity 打包后 Shader 变粉，原因是 Shader 被 Stripping 掉了，解决是加进 Always Included Shaders。」

DSH 会自动：写好笔记 → 开分支 → 提交 → 给你一个链接。

把链接发给管理员（或群里说一声），管理员合并后笔记就正式入库了。

## 遇到问题再看

| 看到 | 做 |
| --- | --- |
| `git 不是内部或外部命令` | 第 ① 步没装 git，回去装 |
| push 被拒 / `non-fast-forward` | 在 DSH 里说「帮我同步一下笔记库」 |
| 提示 `.ps1 禁止运行` | 把命令开头换成 `powershell -ExecutionPolicy Bypass -File ...` |
