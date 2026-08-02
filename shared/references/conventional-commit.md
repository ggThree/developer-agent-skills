# Conventional Commits 参考

Conventional Commits 用结构化标题表达提交意图，便于生成 Changelog、判断版本、检索历史和自动化发布。规范不能替代原子提交与代码审查；错误分类会让自动化产生错误版本。

## 1. 基本格式

```text
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

示例：

```text
fix(auth): 恢复验证码失败后的发送状态
```

```text
feat(api)!: require string values for order status

Align API clients on pending, paid, and closed values.

BREAKING CHANGE: Consumers must send and parse string status values.
```

## 2. 类型选择

| type | 判断标准 | 版本倾向 |
| --- | --- | --- |
| `feat` | 增加用户或调用方可感知能力 | MINOR |
| `fix` | 修正错误行为 | PATCH |
| `docs` | 仅文档内容变化 | 通常不单独提升公开 API 版本 |
| `refactor` | 外部行为不变的结构调整 | 通常不提升功能版本 |
| `perf` | 有依据的性能改进 | 通常 PATCH |
| `test` | 仅测试变化 | 通常不提升功能版本 |
| `style` | 不影响逻辑的格式、空白或展示样式 | 依据产品是否可感知判断 |
| `build` | 构建系统、依赖或制品流程 | 依据兼容影响判断 |
| `ci` | CI/CD 配置 | 通常不提升功能版本 |
| `chore` | 其他维护工作 | 通常不提升功能版本 |
| `revert` | 撤销既有提交 | 按撤销后的用户行为判断 |

版本倾向不是自动结论。任何 type 带 `!` 或 `BREAKING CHANGE:` footer 都意味着破坏性变化，应按 [`semantic-version.md`](semantic-version.md) 评估 MAJOR。

## 3. Scope

Scope 表示稳定模块边界，例如：

```text
fix(payment): 防止重复回调生成两条流水
docs(install): 补充 Claude Code 安装路径
build(ios): 固定依赖解析版本
```

Scope 不应使用临时文件名、个人姓名或含糊的 `misc`。无法确定单一模块时可以省略；若原因是提交包含多个不相关意图，应先拆分。

## 4. Description

- 使用祈使语气，描述完成了什么；
- 中文默认不加句号，英文小写开头且不加句号；
- 不写“修改代码”“更新文件”等无法检索的标题；
- 不写未验证结论，例如没有测试证据却声称“彻底解决”；
- 标题与实际暂存 Diff 一致，而不是与工作区或 Issue 想象一致。

## 5. Body 与 Footer

Body 解释动机、关键行为、边界和替代方案。使用空行与标题分隔。

Footer 常见形式：

```text
Refs: #318
Reviewed-by: Developer Name
BREAKING CHANGE: The legacy numeric status values are no longer accepted.
```

Issue 引用格式以托管平台和仓库规范为准。不能伪造 reviewer、签名或测试结果。

## 6. Breaking Change

以下通常构成破坏性变化：

- 删除、重命名或改变公开 API 字段与语义；
- 提高最低系统/运行时版本；
- 改变持久化格式且旧数据无法读取；
- 修改 CLI 参数、配置键或默认安全行为，使现有调用失败；
- 删除对已发布客户端、插件或扩展的兼容。

以下不一定构成破坏性变化：内部重构、私有 API 调整、向后兼容地增加可选字段。最终以公开契约和使用者影响为准。

## 7. Gitmoji 兼容

Gitmoji 是可选的视觉前缀，不能替代 type。若仓库启用，推荐统一放在 description 前：

```text
feat(search): ✨ 支持按订单号筛选
fix(ios): 🐛 避免重复注册通知 observer
docs: 📝 补充分支恢复流程
```

同一仓库应固定映射，不因 Agent 偏好随机更换 emoji。纯文本日志、无障碍工具和自动化仍应只依赖 Conventional type。

## 8. 提交拆分

适合作为一个 Commit 的内容：

- 同一个可描述、可验证、可回滚的意图；
- 实现与直接对应的测试/文档；
- 为保持构建通过而必需的同一契约变化。

应拆分的内容：

- 独立 bug fix 与无关格式化；
- 依赖升级与业务功能（除非功能直接依赖且无法分离）；
- 多个平台互不依赖的改动；
- 可分别回滚的多个业务目的。

## 9. 生成流程

1. 阅读 `git diff --cached --stat` 和完整暂存 Diff；
2. 用一句话描述提交的单一意图；
3. 选择 type 与稳定 scope；
4. 检查是否存在破坏性变化；
5. 写必要 body/footer；
6. 与实际测试和 Issue 证据核对；
7. 使用 [`../templates/commit_cn.md`](../templates/commit_cn.md) 或 [`../templates/commit_en.md`](../templates/commit_en.md) 输出；
8. 等待用户确认后再 commit。
