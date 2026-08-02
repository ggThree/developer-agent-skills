# Git Skills

Git 分类覆盖从本地差异检查到发布与事故恢复的完整工程链路。所有 Skill 默认证据优先、最小侵入；分析请求保持只读，危险 Git 操作采用逐次确认。

## 能力地图

| Skill | 适用场景 | 核心产出 |
| --- | --- | --- |
| [safe-git-workflow](safe-git-workflow/README.md) | 从检查工作区到安全提交和推送 | 固定检查序列、暂存审查、提交与推送确认门 |
| [review-diff](review-diff/README.md) | 审查工作区、暂存区、提交或分支差异 | 跨栈六项审查报告与风险证据 |
| [commit-message](commit-message/README.md) | 为暂存差异命名或检查提交规范 | 中英文 Conventional Commit、Gitmoji、拆分建议 |
| [release-check](release-check/README.md) | Tag、上架或部署前执行门禁 | 版本、分支、调试残留、依赖锁和是否允许发布 |
| [merge-helper](merge-helper/README.md) | 选择 merge、rebase 或 squash | 分支关系、冲突预判、策略建议和确认命令 |
| [rollback-helper](rollback-helper/README.md) | 撤销文件、暂存、本地或公开提交 | restore、revert、soft/mixed reset 的安全方案 |

## 推荐组合

- 日常提交：`review-diff → commit-message → safe-git-workflow`。
- 发布准备：`review-diff → release-check`，需要创建或推送 Tag 时再进入带确认门的 Git 流程。
- 分支集成：`merge-helper → review-diff → release-check`。
- 线上回退：`rollback-helper` 先区分 Git 历史与外部数据状态，再对新产生的 revert 提交使用 `safe-git-workflow`。

## 安全边界

- 每一次 push、merge、rebase、reset 都需要针对当前精确命令重新确认。
- 禁止 force push、硬重置和批量清理工作区。
- 不覆盖用户已有改动，不把未暂存与已暂存差异混为一个审查范围。
- 不把编译或测试计划写成已运行结果，不把未知远端状态写成已同步。

六个 Skill 共同复用根 `scripts/` 与 `shared/`，但各自保持独立触发、独立说明和可直接验证的真实示例。
