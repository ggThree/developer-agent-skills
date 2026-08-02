# Git 安全操作规则

本规则适用于仓库中的全部 Skill、脚本和 Agent。核心原则是：先建立证据，再解释影响；每个改变历史或远端状态的动作都由用户单独确认。

## 1. 信息来源优先级

按以下顺序判断仓库状态：

1. 当前仓库的 `AGENTS.md`、`CONTRIBUTING.md` 与分支保护说明；
2. `git status`、`git branch -vv` 与目标 Diff；
3. 本地提交图、tracking 配置与 remote 配置；
4. 本轮更新后的远端引用；
5. 用户描述。

用户描述用于确定意图，但不能替代仓库证据。若本地引用未更新，应明确写“远端状态未实时验证”。

## 2. 标准安全流程

按顺序执行并在每一步报告事实：

1. `git status`：确认分支、未跟踪文件、暂存和未暂存内容；需要紧凑清单时再补充 `git status --short --branch`；
2. `git branch -vv`：确认 upstream、ahead/behind 和可能的 gone 状态；
3. `git fetch origin`：仅在 remote 确认为 `origin` 后更新引用；网络失败不得用旧引用冒充最新状态，也不附加会清理引用的参数；
4. `git diff --stat` 与 `git diff`：审查工作区内容；
5. 分析修改目的、影响、风险和测试建议；
6. 等待确认后执行精确的 `git add -- <path>`，不默认使用 `git add .`；
7. `git diff --cached --stat` 与 `git diff --cached`：再次审查实际提交内容；
8. 生成符合 [`../templates/commit_cn.md`](../templates/commit_cn.md) 的 Commit Message；
9. 等待确认后执行 `git commit`；
10. 展示新 Commit、分支关系与待推送范围；
11. 等待新的明确确认后执行 `git push`。

任何一步发现敏感信息、生成物、异常大文件、不相关改动或测试失败，都应停止推进并报告。

## 3. 强制确认矩阵

| 操作 | 执行前必须展示 | 确认要求 |
| --- | --- | --- |
| `git add` | 精确路径与未暂存 Diff 摘要 | 首次暂存确认 |
| `git commit` | 完整暂存 Diff、Commit Message、验证结果 | 独立确认 |
| `git push` | remote、目标分支、待推送 Commit | 每次独立确认 |
| `git merge` | source、target、提交图、冲突预测、验证计划 | 每次独立确认 |
| `git rebase` | onto、被重写提交、是否已共享、恢复点 | 每次独立确认 |
| `git reset` | mode、target、将丢失或保留的内容、备份方案 | 每次独立确认 |
| `git restore` | 精确路径、将被覆盖的工作区内容 | 覆盖内容前确认 |
| `git revert` | 目标 Commit、反向 Diff、副作用 | 生成反向 Commit 前确认 |

一次确认只授权一个已展示的动作，不延伸到后续 `commit`、`push` 或其他分支。

## 4. 明确禁止

- 禁止执行或建议 `git push --force`；需要处理远端历史分歧时，优先停止并设计不重写共享历史的方案。
- 禁止执行或建议执行 `git reset --hard`；即使用户提出也只说明风险并改用 `restore`、`revert`、`reset --soft` 或 `reset --mixed`。
- 禁止用 `rm -rf` 清理仓库或构建问题。
- 禁止在未知工作树中运行会批量覆盖文件的命令。
- 禁止把多个危险动作串联为一条命令，以免绕过中间审查。
- 禁止跳过 Hook、分支保护或签名要求；不得使用 `--no-verify` 规避失败。
- 禁止提交 token、证书私钥、密码、Cookie、个人数据或生产环境配置。

## 5. 脏工作区与用户修改

- 现有修改默认属于用户，Agent 不得擅自还原、暂存或格式化。
- 新任务与现有修改重叠时，先对比目标行并说明冲突；无法安全隔离则请求决定。
- 不把 `git stash` 当作无害动作。它改变工作区并可能遗漏未跟踪文件，使用前同样要说明范围与恢复命令。
- 新文件在纳入提交前必须检查内容、大小、来源和忽略策略。

## 6. 分支与远端安全

- 对 remote 使用 `git remote -v` 核对地址，不从分支名推测托管平台。
- 创建或切换分支前确认起点 Commit，避免从过期本地分支派生。
- 已共享分支默认不重写历史；是否共享根据远端引用、PR 和协作者信息判断。
- `main`、`master`、`develop`、release 分支和受保护分支默认视为高影响目标。
- 关于 merge、rebase 和 squash 的选择见 [`../references/branching.md`](../references/branching.md)。

## 7. 失败处理与恢复点

操作前记录当前分支与 Commit SHA。冲突发生时先保留冲突证据，再选择继续或中止：

- merge 可使用 `git merge --abort` 回到合并前状态；
- rebase 可使用 `git rebase --abort` 回到变基前状态；
- cherry-pick 可使用 `git cherry-pick --abort` 回到操作前状态。

中止命令也会改变工作区，执行前先确认当前冲突文件没有需要另行保存的人工修改。完整回滚报告结构见 [`../templates/rollback_report.md`](../templates/rollback_report.md)。

## 8. 完成标准

只有在以下证据齐全时，才能把 Git 工作流标记为完成：

- 实际提交范围与用户确认一致；
- 暂存区、工作区和未跟踪文件状态已报告；
- Commit Message 与 Diff 匹配；
- 已执行验证与未执行验证明确区分；
- 若已推送，remote、branch 和 Commit SHA 已核对；
- 后续回滚路径清晰且没有隐瞒外部数据副作用。
