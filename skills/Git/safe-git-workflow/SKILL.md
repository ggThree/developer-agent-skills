---
name: safe-git-workflow
description: "执行带分阶段确认门的安全 Git 提交与推送流程。用于用户要求检查工作区、审查差异、暂存、生成提交信息、提交或推送，以及需要避免误提交、错分支、覆盖远端历史的场景。"
---

# 安全 Git 工作流

## 总则

按固定顺序收集证据、分析差异并请求确认。把用户希望提交或推送视为目标，不视为已经授权执行每个写操作。保留用户已有改动，不清理、不覆盖、不扩大暂存范围。

先从宿主提供的当前 `SKILL.md` 路径进入其目录，并用物理路径解析符号链接，将结果记为 `SKILL_DIR`。下列 `../../../` 与 `../` 路径都相对 `SKILL_DIR` 解析；运行脚本前转换为绝对路径，不得相对目标 Git 仓库的当前目录直接执行。

执行前读取目标仓库根 `AGENTS.md` 与项目级规范；存在更严格规则时采用更严格规则。使用以下仓库资源：

- 运行 `../../../scripts/git_summary.sh`、`../../../scripts/git_branch.sh`、`../../../scripts/git_diff_summary.sh` 和 `../../../scripts/git_changed_files.sh` 辅助采集证据。
- 读取 `../../../shared/rules/git.md` 和 `../../../shared/rules/review-rule.md` 约束操作与审查。
- 读取 `../../../shared/risk/critical.md`、`../../../shared/risk/high.md` 评估危险操作。
- 需要提交信息时读取 `../../../shared/templates/commit_cn.md` 或 `../../../shared/templates/commit_en.md`，并遵循 `../commit-message/SKILL.md`。
- 需要技术栈审查时遵循 `../review-diff/SKILL.md` 并按需读取 `../../../shared/adapters/`。

## 固定流程

不得跳步、调序或把多个确认合并为一次长期授权。

### 1. 检查工作区

运行：

```sh
git status
```

确认当前目录属于预期仓库，记录未跟踪、已修改、已删除、已暂存文件；需要紧凑清单时补充运行 `git status --short --branch`。遇到疑似密钥、证书、环境文件或超大二进制文件时停止暂存流程并报告风险。

### 2. 检查分支与上游

运行：

```sh
git branch -vv
```

指出当前分支、upstream、领先或落后状态、detached HEAD，以及是否处于 merge、rebase、cherry-pick 或 bisect 中。无法确认目标分支时只报告，不执行写操作。

### 3. 刷新远端引用

运行：

```sh
git fetch origin
```

该命令会访问网络、可能调用 credential helper，并更新远端跟踪引用与 `FETCH_HEAD`；它不自动 merge、rebase 或修改工作树。用户明确禁止网络访问时跳过并把远端状态标为未知；命令失败时保留错误原文并停止依赖远端新状态的结论。

### 4. 查看差异规模

运行：

```sh
git diff --stat
```

记录 `git status` 是否显示已有暂存内容，但保持本阶段只执行工作区差异统计，不跳过下一步完整差异。

### 5. 查看完整差异

运行：

```sh
git diff
```

完整读取未暂存差异。必要时读取相关调用链、类型、测试和配置，而不是仅凭片段判断。

### 6. 分析并等待第一次确认

先分析前五步得到的工作区差异。若 `git status` 显示用户此前已有暂存内容，再补充运行 `git diff --cached --stat` 与 `git diff --cached`，把这一范围标为“已有暂存”，不得与本轮拟暂存内容混为一谈。

输出以下内容：

1. 当前分支与远端同步状态。
2. 未暂存、已暂存、未跟踪文件清单。
3. 修改目的、行为变化、影响范围和风险。
4. 建议纳入本次提交的精确路径或 hunk。
5. 建议排除的文件及原因。
6. 最小验证命令与已获得的验证证据。

随后明确请求用户确认“是否按所列范围执行 `git add`”。没有本次确认，不得进入暂存步骤。用户改变范围后重新查看对应差异并再次分析。

### 7. 精确暂存

获得确认后，优先按明确路径运行：

```sh
git add -- path/to/file
```

混合了无关改动时使用 `git add -p -- path/to/file`。不得使用会模糊范围的全量暂存，除非用户已看到完整文件清单并明确要求。不得暂存仓库外文件。

### 8. 审查暂存区

运行：

```sh
git diff --cached --stat
git diff --cached
```

确认暂存区只包含已批准内容，检查敏感信息、调试代码、生成物、锁文件、二进制文件和意外删除。发现范围偏差时停止；只提出精确纠正方案，不擅自清空暂存区。

### 9. 再次分析

基于暂存区而非工作区重新输出修改摘要、影响范围、风险和测试状态。暂存区为空、存在未解释的大规模删除或关键验证失败时，不建议提交。

### 10. 生成 Commit Message

根据 `git diff --cached` 生成默认中文 Conventional Commit；用户要求英文或 Gitmoji 时切换格式。保证描述与暂存内容一一对应，不编造工单、测试结果或破坏性变更。

### 11. 等待提交确认

展示完整 Commit Message 和暂存文件清单，明确请求“是否使用该信息执行 `git commit`”。这是独立确认；第一次暂存确认不能替代它。

### 12. 执行提交

仅在确认后运行精确的 `git commit` 命令。提交失败时报告原始错误，不自动绕过 hooks，不使用 `--no-verify`。提交成功后运行 `git status --short --branch` 和 `git show --stat --oneline --decorate HEAD` 核对提交结果。

### 13. 等待推送确认

展示提交哈希、目标 remote、源分支、目标分支、领先/落后状态和将执行的完整 push 命令。明确请求“是否现在推送到该远端分支”。提交确认不等于推送确认。

### 14. 执行推送

仅在本次独立确认后运行普通 push：

```sh
git push origin HEAD:<目标分支>
```

不得 force push，不得自动设置意外 upstream，不得在 push 被拒绝后自行 merge、rebase 或重试危险参数。完成后报告远端、分支、提交哈希和命令结果。

## 危险操作确认规则

每一次 `push`、`merge`、`rebase`、`reset` 都必须在执行前重新展示完整命令、目标、影响、风险和回滚路径，并取得仅针对该次操作的明确确认。即使用户在较早消息中说“全部执行”，到达每个危险操作前仍需再次确认。

始终禁止 `git push --force`、`git push -f` 和 `git reset --hard`，用户确认也不能降低该边界。需要合并时转用 `../merge-helper/SKILL.md`；需要回滚时转用 `../rollback-helper/SKILL.md`。

## 完成报告

报告实际执行的命令、提交哈希、远端分支、验证结果、剩余未提交内容、剩余风险和可执行的回滚方案。不得把命令计划写成已执行事实。
