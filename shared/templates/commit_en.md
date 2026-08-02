# English Commit Message 模板

本模板用于生成英文 `Conventional Commits`。输入必须来自已暂存差异；提交前应再次检查 `git diff --cached`，防止将未审查内容混入提交。

## 输出格式

```text
<type>(<scope>): <imperative summary>

<why the change is needed and how behavior changes; omit for a trivial change>

<issue references or BREAKING CHANGE; omit when not applicable>
```

写作规则：

- `type` 的选择遵循 [`../references/conventional-commit.md`](../references/conventional-commit.md)。
- Summary 使用小写开头的英文祈使句，不使用句号，建议不超过 72 个字符。
- Body 使用现在时，重点解释动机、边界和兼容性，不罗列文件名。
- 未执行的测试写成 `Tests: not run (reason)`，不得写成已通过。
- 若暂存差异同时包含不相关目的，应先建议拆分提交。

## 完整示例

```text
fix(player): prevent duplicate observers after source changes

Remove the previous time observer before attaching a new one so repeated source
updates do not trigger duplicate callbacks.

Refs: #241
```

破坏性变更示例：

```text
feat(api)!: require string values for order status

Align clients and services on pending, paid, and closed status values and remove
the legacy numeric mapping.

BREAKING CHANGE: API consumers must send and parse string status values.
```

提交命令属于有状态操作，必须遵循 [`../rules/git.md`](../rules/git.md) 的确认流程。
