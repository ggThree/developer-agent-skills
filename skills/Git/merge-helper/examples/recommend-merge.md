# 示例：共享功能分支优先 merge

## 用户输入

```text
feature/payment-retry 已有两位同事基于它继续开发。请分析怎么合到 develop，暂时不要执行。
```

## 只读证据

```text
target: develop at 3c912ab
source: feature/payment-retry at 81bd7ef
source ahead: 6
source behind: 4
working tree: clean
source upstream: origin/feature/payment-retry
共同修改文件: PaymentService.java, payment-api.ts
特殊文件: 无锁文件、迁移或二进制变化
```

## 输出

### 分支关系

源分支已发布并被多人依赖，相对 `develop` 领先 6、落后 4；远端引用已刷新，工作区干净。

### 冲突风险

风险为 **Medium**。两侧同时修改 `PaymentService.java` 的重试条件和 `payment-api.ts` 的错误枚举，Git 预演未出现文本冲突，但存在前后端枚举语义不一致的可能。

### 策略比较

- merge：保留既有 6 个提交哈希，不影响同事分支，符合共享分支安全边界。
- rebase：会重写 6 个公开提交；后续同步可能要求 force push，因此不建议。
- squash：能简化目标历史，但丢失两个独立修复提交的可回滚边界，不符合当前审计需求。

### 推荐策略

推荐普通 merge。先在目标分支完成接口枚举集成测试，再保留一个明确 merge commit。

### 验证计划

运行后端支付服务单元测试、前端类型检查，并分别回归可重试错误、不可重试错误和重试上限。

### 回滚方案

合并过程中使用 `git merge --abort`；合并已提交但未推送时保留提交证据后选择安全恢复；合并已公开时使用 `git revert -m 1 <merge-commit>` 创建反向提交。

### 候选命令

```sh
git switch develop
git merge --no-ff feature/payment-retry
```

上述命令尚未执行。若要继续，需要在重新检查分支状态后，对本次 merge 单独确认；合并后的 push 还需再次确认。
