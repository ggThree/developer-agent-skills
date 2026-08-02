# 中文 Commit Message 模板

本模板用于根据已暂存差异生成中文 `Conventional Commits`。生成前必须读取 `git diff --cached --stat` 与 `git diff --cached`；不得根据工作区未暂存内容推测提交范围。

## 输出格式

```text
<type>(<scope>): <中文摘要>

<说明改动动机、核心行为与兼容性影响；简单提交可省略正文>

<关联事项或 BREAKING CHANGE；无对应信息时整段省略>
```

约束：

- `type` 按 [`../references/conventional-commit.md`](../references/conventional-commit.md) 选择。
- `scope` 使用稳定的模块名、包名或平台名；无法准确归类时省略括号。
- 摘要使用祈使语气，说明完成了什么，结尾不加句号，建议不超过 50 个中文字符。
- 正文解释“为什么改”和“行为如何变化”，不逐行复述 Diff。
- 一个提交只表达一个可回滚意图；若暂存内容存在多个独立意图，应建议拆分，而不是编造笼统标题。
- 不写未经 Diff 或测试记录证实的“已修复”“已兼容”“已通过”。

## 类型判断

| 类型 | 使用条件 |
| --- | --- |
| `feat` | 引入用户可感知的新能力 |
| `fix` | 修正错误行为 |
| `docs` | 仅文档变化 |
| `refactor` | 行为不变的结构调整 |
| `perf` | 可解释或可测量的性能改进 |
| `test` | 仅新增或调整测试 |
| `style` | 不影响逻辑的格式或样式调整 |
| `build` | 构建系统、依赖或产物流程变化 |
| `ci` | 持续集成配置变化 |
| `chore` | 不属于上述类型的维护工作 |

## 完整示例

```text
fix(auth): 避免验证码请求失败后按钮持续禁用

在请求的 finally 分支统一恢复 loading 状态，确保网络异常和业务错误均可重新发送验证码。

Refs: #128
```

涉及破坏性变更时：

```text
feat(api)!: 统一订单状态字段为字符串枚举

客户端与服务端统一使用 pending、paid、closed，移除旧的数字状态兼容分支。

BREAKING CHANGE: 调用方必须改用字符串状态值。
```

生成提交信息后仍需等待用户确认，具体安全边界见 [`../rules/git.md`](../rules/git.md)。
