# Git Flow 参考

Git Flow 是围绕长期 `main` 与 `develop` 分支组织 feature、release 和 hotfix 的分支模型。它适合有明确版本发布窗口、需要维护多个发布阶段的团队，但不是所有仓库的默认最佳选择。

## 1. 分支职责

| 分支 | 来源 | 合入目标 | 职责 |
| --- | --- | --- | --- |
| `main` | 已发布历史 | 无固定上游 | 每个发布点可部署，Tag 指向这里的发布 Commit |
| `develop` | `main` 或上个周期 | `main`（经 release） | 集成本周期已完成特性 |
| `feature/<name>` | `develop` | `develop` | 单一功能或修复，不直接承载发布准备 |
| `release/<version>` | `develop` | `main` 与 `develop` | 版本稳定、版本号、发布说明与仅限发布修复 |
| `hotfix/<name>` | `main` | `main` 与 `develop` | 修复当前生产版本的紧急问题 |

如果团队同时维护多个生产版本，应为维护线定义清楚的 release branch 与安全修复回灌策略，不能仅凭分支名字推测。

## 2. Feature 流程

```text
main ────────────────●
                     \
develop ──●──●────────●────
           \          /
feature    ●──●──●───●
```

1. 从已更新的 `develop` 创建语义清楚的 feature 分支。
2. 保持一个分支一个交付意图，定期了解 `develop` 的变化。
3. 提交前审查工作区和暂存区，执行目标测试。
4. 合入方式由仓库策略决定：merge 保留分支，squash 压成原子意图，rebase 只用于未共享历史。
5. 合入后删除远端 feature 分支前确认没有未合入的唯一 Commit。

所有修改状态的 Git 命令遵循 [`../rules/git.md`](../rules/git.md)。

## 3. Release 流程

从 `develop` 创建 `release/<version>` 后进入稳定期：

- 允许版本号、发布说明、构建配置和发布阻断修复；
- 不再引入与该版本无关的新功能；
- 在目标环境执行构建、测试、迁移演练和回滚演练；
- 发布 Commit 合入 `main` 并创建不可移动的 annotated Tag；
- 同一修复回灌 `develop`，避免下一版本重新出现；
- 若 `develop` 已包含结构性变化，回灌应通过审查后的 merge/cherry-pick 完成，不能盲目复制文件。

准入标准见 [`../rules/release-rule.md`](../rules/release-rule.md)，版本规则见 [`semantic-version.md`](semantic-version.md)。

## 4. Hotfix 流程

1. 从当前生产 Tag 对应的 `main` Commit 创建 hotfix 分支。
2. 只修复紧急生产问题，保留复现、监控和影响证据。
3. 执行最小充分验证，建立回滚点。
4. 合入 `main`，按版本策略增加 PATCH 或必要的更高版本。
5. 将修复同步到 `develop` 和仍受支持的维护分支。
6. 验证所有分支使用相同修复语义，不因手工复制产生漂移。

## 5. 优势与成本

### 适合

- 发布周期明确，有专门稳定阶段；
- 需要同时准备下一版本与维护生产版本；
- 合规或审计要求保留发布节点；
- 移动端、桌面端等不能持续即时部署的产品。

### 不适合

- 持续部署且 `main` 始终可发布的小团队；
- 分支停留时间会显著增加集成冲突的仓库；
- 团队无法稳定维护 `develop` 与 release 回灌；
- 只因工具支持而创建大量无业务意义的长期分支。

## 6. 常见失败模式

- `develop` 长期不可用，feature 合入后没有集成验证；
- release 分支继续接受新功能，导致稳定窗口失效；
- hotfix 只进入 `main`，下一版本回归同一问题；
- Tag 指向构建后被修改的 Commit，制品不可追溯；
- 对已共享 feature/release 分支 rebase，破坏协作历史；
- 把分支模型当作质量保证，忽略测试、审查和发布门禁。

## 7. 采用检查清单

采用 Git Flow 前，团队应明确：

- 唯一发布分支和集成分支；
- feature、release、hotfix 的命名和创建权限；
- 每类分支允许的 merge 策略；
- CI 必须通过的门禁和审批人数；
- Tag 创建、签名和制品关联方式；
- hotfix 回灌与多版本维护责任人；
- 分支清理与恢复策略。

若这些规则无法明确，优先采用更简单的短分支或 trunk-based 模型，选择依据见 [`branching.md`](branching.md)。
