# safe-git-workflow

`safe-git-workflow` 为日常 Git 提交与推送提供不可跳过的证据链和确认门，适合多人协作、脏工作区、关键分支和包含多类改动的仓库。

## 能力

- 固定执行 `status → branch -vv → fetch → diff stat → diff → 分析`。
- 在暂存、提交、推送三个阶段分别展示范围并请求确认。
- 区分未暂存、已暂存和未跟踪内容，避免夹带用户改动。
- 对 `push`、`merge`、`rebase`、`reset` 强制逐次确认。
- 默认拒绝 force push 与硬重置。

## 使用方式

在仓库根目录调用：

```text
使用 $safe-git-workflow 检查当前修改，先给出提交范围，不要在我确认前暂存。
```

Skill 会调用仓库根 `scripts/` 中的只读检查脚本，并读取 `shared/rules/`、`shared/risk/`、`shared/templates/` 和 `shared/adapters/` 中与当前项目相关的资料。

## 安全边界

该 Skill 不把“帮我提交”解释成对 push、merge、rebase 或 reset 的永久授权。每个危险操作都需要展示精确命令、目标和回滚路径后再次确认。

完整演练见 [examples/safe-commit-and-push.md](examples/safe-commit-and-push.md)。
