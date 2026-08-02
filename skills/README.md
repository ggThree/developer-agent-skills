# Skills 索引

本目录收录可被 Codex、ChatGPT、Claude Code 与 Cursor 复用的工程化 Skills。每个 Skill 都是独立能力单元，以 `SKILL.md` 定义触发条件和执行规范，以 `agents/openai.yaml` 提供 OpenAI 界面元数据，并用真实示例说明输入与输出。

## 分类

| 分类 | 说明 | 入口 |
| --- | --- | --- |
| Git | 安全提交、差异审查、提交信息、发布门禁、合并策略与回滚决策 | [Git/README.md](Git/README.md) |

## 使用约定

1. 从分类索引选择与当前目标最匹配的单个 Skill；跨阶段任务按工作流显式组合。
2. 在实际仓库根目录调用 Skill，让 Agent 优先读取项目自身的 `AGENTS.md`、构建配置、测试与 Git 证据。
3. 把只读分析和写操作分开。涉及提交、推送、合并、变基或重置时，遵守对应 Skill 的独立确认门。
4. 使用仓库根 `scripts/` 获取可重复的检查结果，使用 `shared/` 中的模板、规则、风险定义、参考资料与技术栈 Adapter 统一输出。

Skill 名称使用小写字母与连字符，目录名与 `SKILL.md` frontmatter 中的 `name` 保持一致。
