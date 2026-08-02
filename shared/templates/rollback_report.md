# Rollback 分析报告模板

Rollback 的目标是恢复可接受状态并保留审计能力，不是简单让 Diff 消失。执行任何恢复命令前，先识别对象、共享状态、数据副作用和可恢复路径。

## 输出结构

### 回滚目标

说明要撤销的具体行为、目标 Commit 或文件、影响环境，以及成功标准。不得使用“回到之前”这类不可验证描述。

### 当前证据

至少记录：

```sh
git status --short --branch
git branch -vv
git log --oneline --decorate -n 20
git diff
git diff --cached
```

如果涉及远端分支，注明远端信息是否经过本次 `fetch` 更新。

### 方式选择

| 场景 | 首选方式 | 关键影响 |
| --- | --- | --- |
| 未暂存的单文件修改 | `git restore -- <path>` | 覆盖工作区内容，执行前保存 Diff |
| 已暂存但未提交 | `git restore --staged -- <path>` | 仅取消暂存，工作区内容保留 |
| 已共享 Commit | `git revert <commit>` | 新增反向 Commit，保留历史 |
| 本地 Commit，保留改动 | `git reset --soft <target>` | 移动分支指针，改动保持暂存 |
| 本地 Commit，取消暂存 | `git reset --mixed <target>` | 移动分支指针，改动保留在工作区 |

禁止执行或建议执行 `git reset --hard`。即使用户主动提出，也只展示其不可恢复风险和安全替代方案，不把确认视为例外授权。

### 副作用分析

检查数据库迁移、已发送消息、支付、对象存储、缓存、搜索索引、外部 API 与客户端版本。Git 回滚不能自动撤销这些外部状态。

### 执行计划与确认点

把每个会修改状态的命令单独列出，并在 `restore`、`revert`、`reset`、`push` 前设置确认点。不得把多个危险命令连接成一条命令。

### 回滚后验证

包含 Diff 检查、构建或测试、关键业务路径、监控指标和数据一致性检查。

## 完整示例

```text
回滚目标：撤销已合并的登录缓存改造 Commit a1b2c3d，恢复 token 只保存在 Keychain 的行为。
当前状态：Commit 已推送到 main，工作区干净，无数据库迁移。
方式：使用 git revert a1b2c3d；不重写 main 历史。
风险：旧版本可能遗留 UserDefaults token，回滚代码后需在启动迁移中清理。
确认点：先审查 revert 生成的 Diff；确认后提交；再次确认后推送。
验证：新登录、升级安装、退出登录与冷启动均不能从 UserDefaults 恢复 token。
```

命令安全规则见 [`../rules/git.md`](../rules/git.md)，风险分级见 [`../risk/`](../risk/)。
