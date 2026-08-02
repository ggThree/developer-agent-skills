# Git 工程最佳实践

本参考把 Git 作为协作、审计和恢复系统使用。最重要的能力不是记住更多命令，而是在执行前准确回答：当前状态是什么、命令会改变什么、失败后如何恢复。

## 1. 每次工作先建立状态

```sh
git status --short --branch
git branch -vv
git remote -v
git log --oneline --decorate -n 15
```

- 确认当前目录属于预期仓库；
- 确认分支、upstream、ahead/behind；
- 区分工作区、暂存区、未跟踪文件和已提交历史；
- remote URL 可能包含敏感信息，展示时应脱敏；
- 远端引用只有在本轮 fetch 后才能代表较新快照。

## 2. 用 Diff 驱动决策

```sh
git diff --stat
git diff
git diff --cached --stat
git diff --cached
```

先看统计识别范围和异常大文件，再读完整 Diff。提交前必须审查 staged Diff，因为它才是 Commit 的真实输入。对 binary、lockfile、工程配置和生成文件，需结合来源工具和上下文判断。

审查输出遵循 [`../templates/review_report.md`](../templates/review_report.md)。

## 3. 原子提交

一个好 Commit 应：

- 只有一个可描述意图；
- 在合理条件下可独立构建或验证；
- 包含与实现直接相关的测试和文档；
- 不混入格式化、依赖升级或个人配置；
- 可以单独 revert，且副作用明确。

使用精确 pathspec 暂存：

```sh
git add -- path/to/file
```

交互式暂存适合拆分同一文件的独立修改，但执行前应理解每个 hunk；不要为获得“干净 Diff”拆坏必要的原子行为。

## 4. Commit Message

默认中文项目使用 [`../templates/commit_cn.md`](../templates/commit_cn.md)，英文协作使用 [`../templates/commit_en.md`](../templates/commit_en.md)。类型、scope、breaking change 与 Gitmoji 规则见 [`conventional-commit.md`](conventional-commit.md)。

Commit Message 解释意图和影响，不复制文件列表。测试结果放在 PR/Review 报告或正文中时必须真实可验证。

## 5. 同步与集成

- fetch 与 merge/rebase 分开，先更新引用、分析提交图，再决定策略；
- 已共享历史默认不 rebase；
- 合并前比较 `target...source`，理解共同祖先；
- 冲突解决要保留双方业务意图，不能机械选择 ours/theirs；
- 合并后审查结果 Diff 并运行受影响测试；
- push 是独立远端写操作，必须在展示 remote、branch 和 Commit 后确认。

策略选择详见 [`branching.md`](branching.md)。

## 6. 恢复优先级

按“最少破坏、最好审计”选择：

1. 未提交文件：保存 Diff 后，按精确路径 `git restore`；
2. 已暂存文件：`git restore --staged` 只取消暂存；
3. 已共享 Commit：`git revert` 新增反向历史；
4. 未共享本地 Commit：确认后使用 `reset --soft` 或 `reset --mixed`；
5. `git reflog` 用于寻找本地引用历史，但不是长期备份策略。

禁止执行 `git reset --hard` 和 `git push --force`，不得通过用户确认降低此边界。完整评估使用 [`../templates/rollback_report.md`](../templates/rollback_report.md)。

## 7. 分支卫生

- 从已确认的起点创建短生命周期分支；
- 名称表达类型和业务意图；
- 频繁小批量集成，避免数周后一次性冲突；
- 删除前确认 PR、merge-base 和唯一 Commit；
- 本地分支 gone 不代表可直接删除，仍需检查未合入提交；
- release/hotfix 的回灌责任写入发布流程。

## 8. 敏感信息与大文件

- 在 commit 前扫描 token、密钥、证书、密码、Cookie、个人数据和生产配置；
- `.gitignore` 只阻止未跟踪文件，不能移除已提交历史；
- 凭证一旦提交或推送，应立即轮换并审计使用，删除文件不是完整修复；
- 大型二进制使用项目既定 Git LFS 或制品仓库，不临时改变存储策略；
- 清理公开历史属于高风险事件，需要备份、协作者协调和托管平台确认。

## 9. 自动化与 Hooks

- Hook 和 CI 应调用仓库版本化脚本，保证本地与流水线行为一致；
- 检查只读信息时保持确定性，不依赖交互式 shell 或本机全局配置；
- 失败信息给出命令、文件和修复方向；
- 不用 `--no-verify` 绕过失败；若 Hook 本身有缺陷，应修复 Hook 并保留审查证据；
- 自动生成 Changelog/版本前先验证 Commit 分类与发布范围。

## 10. 发布可追溯性

一次发布应能从以下对象相互追溯：

```text
需求/PR → Review → Commit → Tag → CI Run → 制品摘要 → 部署记录
```

Tag 指向准确的发布 Commit，制品来自该 Commit，发布说明记录实际验证与风险。版本选择见 [`semantic-version.md`](semantic-version.md)，发布门禁见 [`../rules/release-rule.md`](../rules/release-rule.md)。

## 11. Agent 安全约束

- 读取和分析不等于授权写入；
- 一次确认不覆盖后续 add、commit、push、merge、rebase 或 reset；
- 现有改动默认属于用户，不自动清理或暂存；
- 高风险命令逐条展示影响、备份和回滚，再等待确认；
- 无法验证的远端、CI 或设备结果明确标记，不虚构成功；
- 所有最终报告说明修改范围、验证、残余风险和回滚步骤。

强制规则以 [`../rules/git.md`](../rules/git.md) 为准，本参考用于解释实践理由。
