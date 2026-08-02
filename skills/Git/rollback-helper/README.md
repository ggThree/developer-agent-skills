# rollback-helper

`rollback-helper` 先区分工作区、暂存区、本地历史和公开历史，再选择最小回滚方案。它把数据保留和恢复证据放在命令便利性之前。

## 支持方案

- `git restore --staged`：取消暂存，保留文件修改。
- 精确路径 `git restore`：丢弃已跟踪文件的本地修改，执行前保护差异。
- `git revert`：用新提交撤销已发布提交。
- `git reset --soft`：移动未发布本地历史，保留为已暂存修改。
- `git reset --mixed`：移动未发布本地历史，保留为未暂存修改。

该 Skill 禁止硬重置、`git clean` 和 force push。任何 reset 都要单独确认。

## 使用方式

```text
使用 $rollback-helper 分析如何撤销已推送的支付重试提交；只给方案，不要执行。
```

Skill 复用根 `scripts/rollback_check.sh`，并读取共享 Git 规则、风险定义与回滚报告模板。

公开提交回滚示例见 [examples/revert-published-commit.md](examples/revert-published-commit.md)。
