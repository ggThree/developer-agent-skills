# review-diff

`review-diff` 是面向真实仓库的跨栈 Git 差异审查 Skill。它先界定审查范围，再根据文件和构建证据自动加载 Objective-C、Swift、Vue、React、uni-app、Spring 或 Node Adapter。

## 固定交付

每次审查均输出：

1. 修改摘要
2. 修改原因
3. 影响范围
4. 风险分析
5. 建议测试
6. 建议 Commit Message

风险结论包含触发条件、精确位置、影响、依据、建议和回滚方式；没有证据时保留不确定性，不把猜测写成缺陷。

## 使用方式

```text
使用 $review-diff 审查 develop...feature/session 的差异，重点检查 Swift Concurrency 和接口兼容性。
```

默认不修改目标文件、refs 或暂存内容。Skill 会复用根 `scripts/` 的差异采集能力、`shared/adapters/` 的技术栈清单、`shared/rules/` 的审查规则和 `shared/risk/` 的分级标准。

完整示例见 [examples/swift-session-review.md](examples/swift-session-review.md)。
