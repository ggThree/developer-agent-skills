---
name: merge-helper
description: "比较 merge、rebase 与 squash 策略，分析分支关系、发布状态、历史要求和潜在冲突，并在执行任何合并或变基前建立独立确认门。用于功能分支集成、PR 合并策略选择、线性历史整理、冲突预检和分支同步决策。"
---

# 合并策略助手

## 安全原则

默认只做分析，不把“帮我合并”视为已授权执行。除已披露副作用的 `fetch` 外，不改变工作区内容、refs 或暂存内容。任何 `merge` 或 `rebase` 命令，包括 `merge --squash`，都必须在执行前重新展示源分支、目标分支、精确命令、历史影响、冲突风险和回滚方案，并取得针对该次命令的明确确认。

先从宿主提供的当前 `SKILL.md` 路径进入其目录，并用物理路径解析符号链接，将结果记为 `SKILL_DIR`。下列 `../../../` 路径都相对 `SKILL_DIR` 解析；运行脚本前转换为绝对路径，不得相对目标 Git 仓库的当前目录直接执行。

先读取目标仓库根 `AGENTS.md`、分支保护规则和 CI 配置。使用以下资源：

- 运行 `../../../scripts/merge_check.sh` 和 `../../../scripts/branch_sync.sh` 进行非侵入式预检。
- 结合 `../../../scripts/git_branch.sh`、`../../../scripts/git_diff_summary.sh` 获取分支与差异证据。
- 读取 `../../../shared/references/branching.md`、`git-flow.md` 和 `git-best-practice.md`。
- 读取 `../../../shared/rules/git.md`、`review-rule.md` 以及当前技术栈规则。
- 采用 `../../../shared/templates/merge_report.md` 和 `risk_report.md` 输出分析。
- 按 `../../../shared/risk/high.md`、`medium.md`、`low.md` 评估历史重写与冲突。

## 建立分析上下文

要求明确源分支和目标分支。用户未说明时，从当前分支与 upstream 推断候选，但必须把推断标出，不执行操作。

依次运行分析命令与远端刷新步骤；其中 `fetch` 具有网络和引用更新副作用：

```sh
git status --short --branch
git branch -vv
git fetch origin
git merge-base <target> <source>
git rev-list --left-right --count <target>...<source>
git log --oneline --decorate --graph <target>..<source>
git diff --stat <target>...<source>
git diff --name-status <target>...<source>
```

检查工作区是否干净、是否存在进行中的 Git 操作、两个引用是否存在、upstream 是否同步、源分支是否已发布或被多人使用。执行 `fetch` 前说明它会访问网络、可能调用 credential helper，并更新远端跟踪引用与 `FETCH_HEAD`；用户禁止网络访问或命令失败时，把远端新鲜度标为未知。

## 预判冲突

从共同祖先分别获取两侧改动文件，找出交集；在 Git 版本支持时运行隔离对象目录的 `git merge-tree` 预演，不向真实对象目录写入预演对象。重点升级以下冲突信号：

- 两侧修改同一函数、接口、数据库迁移或配置键。
- 一侧重命名或删除、另一侧继续编辑同一路径。
- 同时修改 `project.pbxproj`、依赖锁、生成文件、二进制文件或本地化资源。
- 源分支长期落后，或两侧提交数量较多且包含跨模块重构。
- 冲突后的选择会改变鉴权、支付、数据结构、签名或发布配置。

“未发现同文件改动”只能表示冲突概率较低，不能保证语义兼容。仍需检查接口、类型、测试和构建关系。

## 选择策略

### 选择 merge

满足以下特征时优先建议普通 merge：

- 源分支已经推送、共享或被其他分支引用。
- 需要保留完整分支拓扑和原始提交哈希。
- 仓库允许 merge commit，且避免改写历史比线性外观更重要。
- 合并长期分支、release 分支或多人协作分支。

代价是产生 merge commit，历史可能更复杂。它不会重写既有提交，通常是共享分支的低风险选择。

### 选择 rebase

仅在以下条件同时成立时建议 rebase：

- 源分支尚未共享，或所有协作者已明确协调历史重写。
- 仓库要求线性历史。
- 目标是把少量、清晰、可独立验证的本地提交重放到最新基线。
- rebase 后不需要 force push。

rebase 会改变提交哈希。源分支已公开且后续必须 force push 时，不建议使用；本仓库禁止用 force push 完成该路径。交互式修改提交还会扩大判断范围，不应擅自执行。

### 选择 squash

满足以下特征时建议 squash：

- 功能分支包含多个修正、试验或临时提交，但整体是一个原子变更。
- 目标分支只需要一个清晰提交，不要求保留分支内部审计轨迹。
- PR 平台或仓库规范明确采用 squash。

squash 丢失目标分支中的逐提交边界和原始作者语义。涉及合规审计、多个可独立回滚功能或有价值提交序列时不要使用。

## 给出结论

按以下顺序报告：

1. **分支关系**：源、目标、共同祖先、领先/落后、远端同步状态。
2. **工作区门禁**：是否干净，是否有进行中的 Git 操作。
3. **冲突风险**：文件交集、语义热点、风险等级和证据。
4. **策略比较**：merge、rebase、squash 各自适用性和历史影响。
5. **推荐策略**：只推荐一个首选，并说明拒绝其他方案的具体原因。
6. **验证计划**：合并后应运行的测试、构建和人工回归。
7. **回滚方案**：执行前、未推送后和已推送后的可恢复方式。
8. **候选命令**：展示但不执行。

## 执行确认门

用户选择策略后，重新运行 `git status --short --branch`、`git branch -vv` 和必要的远端刷新，确认分析未过期。随后展示：

- 当前检出的目标分支。
- 源分支与精确提交范围。
- 完整 `merge`、`rebase` 或 `merge --squash` 命令。
- 是否创建提交、是否改写哈希、预期冲突文件。
- 中止方式：`git merge --abort` 或 `git rebase --abort`。
- 已完成后的回滚方案。

明确询问是否执行“这一条”命令。没有新确认不得执行；此前对分析、fetch、暂存或提交的确认均不能替代。

执行发生冲突时立即停止，列出 `git status` 与冲突文件，解释 ours/theirs 相对当前操作的含义。不得自动选择一侧、不得批量接受冲突、不得继续提交，除非用户审阅解决方案并确认。

## 合并后验证

成功后检查 `git status`、`git log --graph`、最终 diff、测试和构建。squash 只更新工作区与暂存区时，按 `../safe-git-workflow/SKILL.md` 审查暂存差异并单独确认 commit。任何 push 都必须再次展示远端和目标分支并取得新的确认；禁止 force push。
