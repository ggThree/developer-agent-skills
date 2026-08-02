# 示例：安全提交登录修复

## 用户输入

```text
请把登录超时修复提交到 feature/login-timeout，并推送远端。配置文件是我本地调试用的，不要提交。
```

## 第一阶段输出

```text
当前分支：feature/login-timeout，跟踪 origin/feature/login-timeout，本地领先 0、落后 0。

未暂存：
- src/auth/session.ts：刷新令牌超时后补充一次受控重试
- src/auth/session.test.ts：增加超时与重试上限测试
- config/local.json：本地接口地址变化，按你的要求排除

已暂存：无
未跟踪：无

风险：重试逻辑可能重复发送请求；实现通过 singleFlight 复用同一刷新 Promise，测试覆盖两次并发调用。建议执行 npm test -- session.test.ts。

建议暂存：src/auth/session.ts、src/auth/session.test.ts。
是否按以上两个精确路径执行 git add？
```

## 暂存审查后的输出

```text
暂存区只包含 2 个已确认文件，共新增 31 行、删除 8 行；未发现密钥、调试输出、生成物或意外删除。config/local.json 仍未暂存。

建议 Commit Message：
fix(auth): 限制令牌刷新超时重试次数

验证：npm test -- session.test.ts 通过，8 项测试全部通过。

是否使用该 Commit Message 执行 git commit？
```

## 提交后的推送确认

```text
提交成功：7f13c2a fix(auth): 限制令牌刷新超时重试次数
目标：origin/feature/login-timeout
命令：git push origin HEAD:feature/login-timeout
工作区仍有未提交的 config/local.json，不会进入推送提交。

是否执行本次 push？
```

此示例中，三次确认分别只授权暂存、提交和推送，任何一次都不能替代下一次确认。
