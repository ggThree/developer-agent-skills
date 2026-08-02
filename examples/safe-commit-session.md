# 示例：安全提交会话

## 用户输入

```text
$safe-git-workflow 帮我把登录超时修复整理成一个中文提交。不要包含本地 Xcode 配置；push 前必须问我。
```

## 第一阶段证据

```text
分支：fix/login-timeout，跟踪 origin/fix/login-timeout，ahead 0 / behind 0
工作区：3 个已修改文件，1 个未跟踪文件
差异：18 insertions(+), 6 deletions(-)
未跟踪：App.xcworkspace/xcuserdata/dev.xcuserdatad/
```

## Agent 分析

- 业务差异集中在 `LoginService.m`、`LoginViewModel.m` 和对应测试，范围与登录超时修复一致。
- `xcuserdata` 是本机用户状态，不应进入提交。
- 修改调整了超时错误映射，需要回归弱网、取消请求和重复点击。
- 当前只获得“整理提交”的目标，尚未获得暂存授权。

## 第一次确认

```text
建议仅暂存以下文件：
- Sources/Login/LoginService.m
- Sources/Login/LoginViewModel.m
- Tests/LoginViewModelTests.m

是否允许执行精确 git add？
```

用户确认后，Agent 精确暂存并再次读取 `git diff --cached`。

## 暂存区复审

```text
暂存区仅含 3 个目标文件；未包含 xcuserdata。
测试新增了超时映射与取消请求两个用例。
建议提交信息：fix(login): 修正弱网超时的错误状态映射
```

## 第二次确认

Agent 询问是否允许使用上述 Commit Message 执行 `git commit`。提交成功后返回提交哈希与实际文件数，但不自动 push。

## 第三次确认

```text
本地分支现在领先 origin/fix/login-timeout 1 个提交。
是否允许推送到 origin/fix/login-timeout？该确认只适用于本次 push。
```

只有用户明确确认后才执行 push。任何先前确认都不能替代该步骤。
