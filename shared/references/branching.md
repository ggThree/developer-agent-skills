# 分支策略参考

分支策略应服务发布频率、协作规模、审计与回滚需求。没有一种模型适合全部仓库；选择前先建立团队事实，而不是按平台默认按钮决定。

## 1. 三种常见模型

| 模型 | 核心结构 | 适合场景 | 主要成本 |
| --- | --- | --- | --- |
| Trunk-Based Development | `main` + 极短期分支或直接小提交 | 高频集成、强 CI、feature flag 完善 | 对自动化、兼容发布和小批量交付要求高 |
| GitHub Flow | `main` + 短期 PR 分支 | Web 服务、持续部署、清晰 PR 审查 | 长期版本维护需额外策略 |
| Git Flow | `main` + `develop` + feature/release/hotfix | 固定发布窗口、多发布阶段、客户端产品 | 长期分支多，回灌和冲突成本高 |

Git Flow 细节见 [`git-flow.md`](git-flow.md)。

## 2. 选择问题

按顺序回答：

1. `main` 是否必须始终可部署？
2. 发布是持续进行，还是按版本窗口进行？
3. 是否并行维护多个生产版本？
4. 是否具备快速、可靠的自动化测试和 feature flag？
5. 是否需要保留合并节点用于审计？
6. 分支通常由一个人还是多人共享？
7. 客户端、数据库和 API 是否需要兼容发布窗口？

若无法回答，应先收集 CI、发布和协作数据，不通过增加分支解决流程不清。

## 3. 分支命名

推荐结构：

```text
feature/login-rate-limit
fix/order-idempotency
release/2.4.0
hotfix/payment-callback
docs/install-guide
```

命名要求：

- 小写、短横线、描述业务意图；
- 类型与用途一致，不使用个人姓名作为唯一语义；
- Issue ID 可附加，但不能替代可读描述；
- 避免把环境名与永久分支混为一谈，除非部署体系明确依赖。

## 4. Merge、Rebase 与 Squash

### Merge

选择 merge 当：

- 分支已共享，不能安全重写 Commit SHA；
- 分支内部提交具有审计或二分价值；
- 需要清晰保留并行开发与集成节点。

代价是历史可能出现更多 merge Commit；通过小分支和清晰 Commit 控制复杂度。

### Rebase

选择 rebase 当：

- 提交尚未共享，或所有协作者明确同意重写；
- 需要把本地工作建立在更新基线上；
- 每个 Commit 在变基后仍能独立表达和验证。

变基会改变 Commit SHA。执行前记录原分支引用和目标 `onto`，冲突解决后审查完整区间，不只看最后一个文件。

### Squash

选择 squash 当：

- 分支包含大量 fixup/试验提交；
- 对主线最有价值的是一个原子交付意图；
- 不需要保留每个中间 Commit 的审计语义。

Squash 后的 Commit Message 应覆盖完整变化，不能沿用最后一个碎片提交标题。

### 决策顺序

```text
历史已共享？ ─ 是 → 默认 merge 或平台 squash，不 rebase
       │
       否
       ↓
中间 Commit 有独立价值？ ─ 是 → rebase 整理后保留提交
       │
       否
       ↓
                     squash 为单一原子提交
```

实际操作必须遵守 [`../rules/git.md`](../rules/git.md) 的逐次确认。

## 5. 分支保护

主分支至少考虑：

- 禁止直接 push；
- 必须通过 PR 与规定数量 Review；
- 必须通过目标 CI、测试和安全检查；
- 要求分支为最新或使用 merge queue；
- 限制管理员绕过；
- 要求签名 Commit/Tag（按团队威胁模型）；
- 禁止删除受保护分支与强制更新。

规则应与托管平台实际设置核对，文档声明不能替代平台保护。

## 6. 长期分支治理

- 明确 owner、来源、合入目标和关闭条件；
- 定期检查与目标分支的距离和冲突热点；
- 通过兼容改动和小批量合入缩短存活时间；
- 删除前使用 `git branch --merged`、提交图与 PR 状态确认没有唯一工作；
- 不把环境分支作为唯一部署记录，部署应追溯到不可变 Commit/Tag 与制品。

## 7. 冲突处理原则

冲突解决不是选择“ours/theirs”后完成。应理解双方意图，尤其检查：

- lockfile 与依赖树；
- Xcode `project.pbxproj`、资源和 Target Membership；
- 数据库 migration 顺序；
- API DTO 与调用方；
- 路由、权限与全局配置；
- 生成文件与其源文件是否一致。

解决后审查合并结果相对两个 parent 的差异，并运行受影响验证。报告格式使用 [`../templates/merge_report.md`](../templates/merge_report.md)。
