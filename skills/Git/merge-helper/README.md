# merge-helper

`merge-helper` 用分支关系、共享状态和冲突证据选择 merge、rebase 或 squash，不以“历史更漂亮”替代安全判断。

## 能力

- 计算共同祖先、领先/落后与提交范围。
- 识别同文件、重命名/删除、锁文件、`project.pbxproj` 和迁移脚本等冲突热点。
- 比较三种策略的历史影响、协作风险与回滚方式。
- 在任何 merge、rebase 或 squash 命令前建立独立确认门。
- 合并后要求重新审查、测试；push 另行确认。

## 使用方式

```text
使用 $merge-helper 分析 feature/session 合入 develop，比较 merge、rebase 和 squash；先不要执行。
```

Skill 调用根 `scripts/merge_check.sh` 与 `branch_sync.sh`，并读取 `shared/references/` 的分支策略、`shared/rules/` 的操作规范及共享风险定义。

分析示例见 [examples/recommend-merge.md](examples/recommend-merge.md)。
