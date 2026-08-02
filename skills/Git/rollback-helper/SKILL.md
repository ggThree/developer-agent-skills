---
name: rollback-helper
description: "为未提交改动、暂存内容、本地提交和已发布提交设计可恢复的 Git 回滚方案，支持 restore、revert、reset --soft 与 reset --mixed，并禁止使用 reset --hard。用于撤销文件修改、取消暂存、反向提交、移动本地分支指针和事故恢复分析。"
---

# 安全回滚助手

## 核心约束

先保护证据和可恢复性，再选择命令。默认只分析和展示计划；`restore`、`revert`、任何 `reset` 以及后续 push 均不得因用户一句“回滚”而自动执行。每次操作前展示精确目标、会改变的 Git 区域、数据保留情况和恢复路径，并取得本次独立确认。

禁止执行 `git reset --hard`，也不把它作为默认候选。禁止用 `git clean`、强制覆盖或 force push 代替回滚。优先保留工作区内容和公开历史。

先从宿主提供的当前 `SKILL.md` 路径进入其目录，并用物理路径解析符号链接，将结果记为 `SKILL_DIR`。下列 `../../../` 路径都相对 `SKILL_DIR` 解析；运行脚本前转换为绝对路径，不得相对目标 Git 仓库的当前目录直接执行。

读取目标仓库根 `AGENTS.md` 与仓库恢复规范。使用以下资源：

- 运行 `../../../scripts/rollback_check.sh` 获取只读回滚上下文。
- 结合 `../../../scripts/git_summary.sh`、`git_branch.sh` 和 `git_diff_summary.sh` 确认影响。
- 读取 `../../../shared/rules/git.md`、`../../../shared/references/git-best-practice.md`。
- 读取 `../../../shared/risk/critical.md`、`high.md` 和 `medium.md`。
- 采用 `../../../shared/templates/rollback_report.md` 与 `risk_report.md` 输出方案。

## 收集证据

依次运行：

```sh
git status --short --branch
git branch -vv
git log --oneline --decorate -12
git reflog -12 --date=iso
git diff --stat
git diff
git diff --cached --stat
git diff --cached
```

对目标提交运行 `git show --stat --summary <commit>` 和 `git show <commit>`。判断改动位于工作区、暂存区、本地提交还是已推送历史；检查是否为 merge commit、是否有后续依赖提交、是否涉及数据库迁移、版本、锁文件、签名、敏感数据或跨服务协议。

无法唯一确定目标路径、提交或发布状态时停止在方案阶段，不猜测引用。不要执行会覆盖未保存内容的操作来“试试看”。

## 选择最小方案

### 取消暂存但保留文件修改

使用：

```sh
git restore --staged -- <path>
```

该命令只把路径移出暂存区，工作区内容保留。仍需展示路径并确认，避免改变用户原有暂存边界。

### 丢弃未提交的已跟踪文件修改

候选命令：

```sh
git restore --source=HEAD -- <path>
```

该操作会覆盖指定路径的工作区修改，无法从普通工作区状态直接找回。执行前先展示 `git diff -- <path>`，建议把所需内容保存为精确 patch 或复制到用户确认的位置，再请求确认。不得使用宽泛的 `.` 覆盖未知范围。`restore` 不处理未跟踪文件，不要附带清理命令。

### 撤销已发布提交

优先使用：

```sh
git revert <commit>
```

`revert` 创建一个反向提交，保留公开历史，适合已推送或多人依赖的分支。先检查目标提交之后是否有依赖变更；反向应用可能产生冲突或破坏后续代码。展示自动生成信息或建议 Commit Message，并在执行前确认。冲突时使用 `git revert --abort` 回到操作前状态，不自动选择冲突一侧。

目标是 merge commit 时读取父提交列表和原合并方向；只有确认主线父节点后才考虑：

```sh
git revert -m <parent-number> <merge-commit>
```

不得默认猜测 `-m 1`。解释 revert merge 会影响未来重新合并的可达性语义，并要求更高等级验证。

### 撤销未发布提交并保留为已暂存修改

仅对确认未共享的本地提交考虑：

```sh
git reset --soft <target>
```

该命令移动当前分支和 HEAD，保留工作区并把差异保留在暂存区。它会改写本地分支历史；执行任何 reset 前必须重新确认目标哈希、将被移除的提交列表和备份引用。

### 撤销未发布提交并保留为未暂存修改

仅对确认未共享的本地提交考虑：

```sh
git reset --mixed <target>
```

该命令移动当前分支和 HEAD，重置暂存区，但保留工作区文件。它可能打乱已有暂存边界，因此执行前要分别记录工作区与暂存区差异，列出会变成未暂存状态的路径，并取得本次 reset 的独立确认。

## 决策顺序

按以下优先级选择：

1. 只需取消暂存：`restore --staged`。
2. 只需丢弃一个已跟踪路径的未提交修改：精确路径 `restore`，先保护 patch。
3. 提交已推送或被他人依赖：`revert`。
4. 提交仅存在本地且需要重新整理：在 `reset --soft` 与 `reset --mixed` 中选择保留暂存边界更多的方案。
5. 目标混合了已发布和未发布历史：不要组合猜测；先建立提交关系图并拆分恢复步骤。

如果安全目标能通过新增修复提交完成，比较该方案与 revert 的影响。涉及数据库、外部消息、对象存储、支付或已下发客户端时，Git 回滚只恢复代码，不会自动恢复外部状态；必须列出对应业务补偿与数据备份要求。

## 执行前报告与确认

固定输出：

1. **当前状态**：分支、upstream、工作区、暂存区、目标提交及是否公开。
2. **目标解释**：用户希望撤销什么，哪些内容必须保留。
3. **方案比较**：restore、revert、soft reset、mixed reset 中适用项与拒绝项。
4. **推荐方案**：精确命令、路径或哈希，不使用模糊引用。
5. **影响范围**：HEAD、分支、暂存区、工作区、远端分别如何变化。
6. **风险与验证**：按等级列触发条件、影响和检查步骤。
7. **备份与回滚**：patch、备份引用、abort 或反向操作方式。
8. **确认问题**：明确询问是否执行这一条命令。

任何 reset 都要在执行前再次运行状态检查，并获得仅针对该次 reset 的明确确认。创建备份分支也是写操作，应先展示名称和指向并请求授权。不得把备份计划写成已完成事实。

## 执行后验证

运行 `git status --short --branch`、`git diff`、`git diff --cached` 和 `git log --oneline --decorate`，确认实际状态与预期一致。执行项目最小测试并报告真实结果。若产生 revert 提交，按 `../safe-git-workflow/SKILL.md` 审查后续 push，并再次确认远端和目标分支。
