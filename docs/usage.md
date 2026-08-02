# 使用

## 使用方式

每个 Skill 支持两种入口：宿主根据 `description` 自动触发，或用户显式指定 Skill。对提交、发布、合并和回滚等高风险任务，推荐显式调用并写清目标分支、允许的操作和禁止项。

```text
$safe-git-workflow 检查当前仓库。允许分析和暂存建议，不允许提交或推送，直到我逐步确认。
```

不同宿主的显式前缀可能是 `$`、`@` 或 `/`，但 Skill 内部流程与输出契约保持一致。

## 推荐会话结构

1. 描述目标，例如“准备一个可审查的修复提交”。
2. 声明边界，例如“不执行 push，不修改依赖”。
3. 给出上下文，例如目标分支、Issue、发布版本和重点风险。
4. 要求 Agent 先运行非侵入式检查脚本并引用证据。
5. 逐步确认暂存、提交和远端操作，不一次授权全部写操作。

## Skill 调用示例

### 安全提交

```text
$safe-git-workflow 为当前修复准备中文提交。先审查全部差异；不要暂存生成文件；每个写步骤等待我确认。
```

### 跨栈审查

```text
$review-diff 审查当前分支相对 origin/main 的差异。重点检查 Objective-C 生命周期、Vue loading 复位和 Spring 事务边界。
```

### Commit Message

```text
$commit-message 根据暂存区差异生成 3 个候选：中文 Conventional Commit、英文 Conventional Commit、中文 Gitmoji。不要执行 commit。
```

### 发布检查

```text
$release-check 检查 v2.4.0 发布条件。目标分支 main，要求工作区干净、版本一致、Tag 不存在且无调试输出。
```

### 合并策略

```text
$merge-helper 比较 feature/payment 相对 origin/main 的 merge、rebase、squash，检查可能冲突并给出推荐，不执行任何合并操作。
```

### 回滚方案

```text
$rollback-helper 设计撤销提交 abc1234 的方案。提交已经推送且被其他人拉取，必须保留公共历史。
```

## 直接使用脚本

所有脚本从目标 Git 仓库根目录执行；也可以通过绝对路径调用本仓库脚本。

| 脚本 | 作用 | 是否写仓库 |
| --- | --- | --- |
| `git_summary.sh` | 汇总仓库、分支、状态和差异规模 | 否 |
| `git_branch.sh` | 展示本地分支、上游和 ahead/behind | 否 |
| `git_diff_summary.sh` | 汇总工作区或指定基线差异 | 否 |
| `git_changed_files.sh` | 分类列出变更文件 | 否 |
| `git_commit_check.sh` | 检查暂存区和提交前条件 | 否 |
| `release_check.sh` | 生成发布门禁结论 | 否 |
| `merge_check.sh` | 分析分叉、冲突和合并策略 | 否 |
| `rollback_check.sh` | 分析提交状态和回滚选择 | 否 |
| `branch_sync.sh` | 基于本地远端跟踪引用判断同步状态 | 否 |

使用 `--help` 查看每个脚本的参数。退出码遵循以下统一契约：

| 退出码 | 含义 |
| --- | --- |
| `0` | 检查完成且没有阻断项 |
| `1` | 检查完成，但发现阻断项或不建议继续 |
| `2` | 参数或用法错误 |
| `3` | 当前目录不是 Git 工作树 |
| `4` | 缺少执行检查所需的对象或变更 |
| `5` | 引用、分支或比较基线无效 |
| `6` | 安全策略明确拒绝的操作 |
| `127` | 缺少必需命令或无法加载可信公共库 |
| `129` | 收到 HUP 并安全中止 |
| `130` | 收到 INT 并安全中止 |
| `143` | 收到 TERM 并安全中止 |

单一来源与公共函数说明见 [`shared/scripts/README.md`](../shared/scripts/README.md)。

## 输出解读

Skill 报告会把发现分为：

- **事实**：命令输出、文件位置、分支关系、匹配行；
- **推断**：基于事实对影响和原因的解释；
- **未知**：缺少运行环境、后端状态、设备或权限而无法验证的内容；
- **风险**：按 Critical、High、Medium、Low 分级；
- **建议**：验证、修改、确认和回滚步骤。

“允许发布”只代表本仓库定义的静态门禁通过，不等于生产部署已获批准，也不能替代 CI、签名、设备回归和业务审批。

## 完整示例

- [Objective-C Diff 审查](../examples/review-objective-c.md)
- [安全提交会话](../examples/safe-commit-session.md)
- [发布被阻断](../examples/release-blocked.md)
