# 示例：撤销已发布的限流配置提交

## 用户输入

```text
提交 9e12b6a 把生产支付限流阈值改错了，已经推送到 main。请给出最安全回滚方案，先不要执行。
```

## 只读证据

```text
current branch: main
upstream: origin/main
working tree: clean
HEAD: c72af91 docs: 更新发布说明
target: 9e12b6a fix(payment): 调整支付限流阈值
target parents: 1
origin/main contains target: yes
later commits depend on changed config key: no
```

## 输出

### 当前状态

目标提交已经位于公开的 `origin/main`，其后有一个仅修改文档的提交。工作区干净，目标不是 merge commit。

### 目标解释

需要撤销 `9e12b6a` 对生产支付限流值的修改，同时保留之后的发布说明和公开提交历史。

### 方案比较

- `restore` 只处理文件状态，不能安全撤销公开提交。
- `revert` 创建可审计的反向提交，不改写 `main` 历史，适用。
- soft/mixed reset 会移动公开分支历史并导致远端分叉，不适用。

### 推荐方案

```sh
git revert 9e12b6a
```

该命令会创建一个新提交，不会删除原提交。执行前应再次确认当前 HEAD、目标提交 diff 和自动生成的反向 diff。

### 影响范围

HEAD 将新增一个 revert 提交；工作区与暂存区在成功后保持干净；远端在另行 push 前不变化。只恢复限流配置，不影响后续文档提交。

### 风险与验证

风险为 **High**：阈值回退会立即改变生产流量行为。运行配置解析测试，并在预发布环境验证超限响应、监控告警和默认值。Git 回滚不自动撤销配置中心已经人工修改的数据，应单独核对外部状态。

### 备份与回滚

若 revert 过程中冲突，使用 `git revert --abort`。若反向提交本身验证失败且尚未推送，可保留证据后再设计撤销该 revert 的新方案。

### 确认问题

是否在重新核对状态后执行本次 `git revert 9e12b6a`？该确认只授权 revert；后续 push 需要再次确认。
