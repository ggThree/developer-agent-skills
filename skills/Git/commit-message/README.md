# commit-message

`commit-message` 从真实 Git 差异生成可追溯的提交信息，而不是根据分支名或用户一句话猜测内容。

## 支持格式

- 中文或英文。
- Conventional Commit。
- Gitmoji 与 Conventional Commit 组合。
- `feat`、`fix`、`docs`、`refactor`、`perf`、`test`、`style`、`build`、`ci` 九类自动判断。
- 原子性检查和多提交拆分建议。

## 使用方式

```text
使用 $commit-message 分析暂存区，给我中文、英文和 Gitmoji 三个版本；不要提交。
```

默认以 `git diff --cached` 为唯一正式输入，并结合仓库历史与 `shared/references/conventional-commit.md` 判断文本格式。根 `scripts/git_commit_check.sh` 只检查暂存内容、敏感信息和提交前条件，不校验 Commit Message 文本。

真实输入输出见 [examples/multilingual-fix.md](examples/multilingual-fix.md)。
