# 示例：生成三种提交信息

## 用户输入

```text
暂存区是支付结果轮询修复。请生成中文、英文和 Gitmoji 版本，不要执行 commit。
```

## 已暂存证据

```text
src/payment/usePaymentPolling.ts      | 18 +++++++++++-------
src/payment/usePaymentPolling.test.ts | 24 ++++++++++++++++++++++++
```

差异显示：组件卸载时新增 AbortController 取消请求；轮询完成后清理 timer；测试覆盖卸载与成功结束路径。

## 输出

### 范围判断

两个文件都服务于同一个支付轮询生命周期修复，适合作为一个原子提交。

### 类型判断

- Type：`fix`
- Scope：`payment`
- 依据：生产逻辑修复卸载后仍请求与 timer 未释放的问题；测试是同一修复的验证，不应单独把整体归为 `test`。

### 推荐版本（中文）

```text
fix(payment): 清理支付轮询请求与定时器
```

### 可选版本

英文：

```text
fix(payment): cancel payment polling and clear its timer
```

Gitmoji：

```text
🐛 fix(payment): 清理支付轮询请求与定时器
```

### 拆分建议

无需拆分；测试与实现属于同一行为变更。

### 校验结果

- 暂存内容检查：已运行 `git_commit_check.sh`，退出码为 `0`，未发现提交前阻断项；该脚本没有校验标题文本。
- 文本规则判断：Skill 按 Conventional Commit 参考规则确认 type 属于允许集合、scope 简短且标题未以句号结尾。

此过程未执行 `git commit`。
