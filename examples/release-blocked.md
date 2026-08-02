# 示例：发布检查被阻断

## 用户输入

```text
$release-check 检查当前 main 是否可以发布 v3.2.0，只做检查。
```

## 检查证据

```text
Branch: main
Tracking: origin/main
Ahead/Behind: 0/0
Working tree: modified package.json, untracked debug.log
Version: package.json=3.2.0
Tag: v3.2.0 not found
Debug findings: src/payment/submit.ts contains console.log
Lockfile: package-lock.json unchanged while package.json dependencies changed
```

## 发布结论

**不允许发布。** 发现三个阻断项：

1. **High：工作区不干净**
   - `package.json` 未提交，`debug.log` 未跟踪；当前构建不可由提交唯一复现。
2. **High：依赖清单与锁文件可能不一致**
   - `package.json` 的 dependencies 有变化，但 `package-lock.json` 没有对应差异。
3. **Medium：支付路径残留调试输出**
   - `src/payment/submit.ts` 存在 `console.log`，可能泄露请求上下文或制造生产噪声。

## 最短修复与复查路径

1. 确认 `package.json` 变化是否属于本次发布；若属于，使用项目锁定的包管理器更新锁文件并审查 Diff。
2. 删除或改为项目统一的脱敏日志接口，并运行支付回归测试。
3. 将 `debug.log` 移出仓库工作区或加入合理忽略规则；不要提交真实日志。
4. 提交后在 `main` 重新运行项目测试、构建和 `release_check.sh --strict`，并人工核对脚本识别出的版本号是否为 `3.2.0`。
5. 全部门禁通过后，单独确认创建 Tag 和推送；检查本身不执行这些操作。

## 回滚建议

若依赖变化不属于本次发布，仅恢复 `package.json` 中对应的精确差异；不要丢弃其他未提交修改。若修复已形成新提交但尚未共享，可在保留备份分支后重新整理；已共享提交使用 `revert`。
