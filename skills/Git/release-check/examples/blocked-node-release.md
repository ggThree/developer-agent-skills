# 示例：Node 发布被依赖锁与调试日志阻断

## 用户输入

```text
使用 $release-check 检查 release/2.4.0，准备创建 v2.4.0。不要修改文件或创建 Tag。
```

## 检查证据

```text
Branch: release/2.4.0...origin/release/2.4.0
Status: clean
HEAD: a31d5c8
package.json version: 2.4.0
Tag v2.4.0: 不存在
Changed since v2.3.2: package.json, src/api/client.ts
package-lock.json: 未随 package.json 依赖变化
src/api/client.ts:77: console.log("accessToken", token)
npm test: 126 passed
npm run build: passed
```

## 输出

### 候选版本

- Commit：`a31d5c8`
- Branch：`release/2.4.0`，与 upstream 同步
- Version：`2.4.0`
- Planned Tag：`v2.4.0`，当前本地与已刷新远端均不存在
- Baseline：`v2.3.2`

### 检查结果

- Git 工作区：通过。
- 遗留标记：未发现阻断项。
- 调试代码：发现 1 处生产代码敏感日志。
- 依赖：`package.json` 改变依赖，`package-lock.json` 未同步。
- 版本与 Tag 命名：一致。
- 测试与构建：实际运行并通过。

### 阻断项

1. **Critical｜访问令牌输出到控制台**：`src/api/client.ts:77` 会在生产请求路径记录 token，可能泄露认证凭据。删除该日志并复查构建产物；回滚时只恢复对应日志删除 hunk。
2. **High｜依赖清单与锁文件不一致**：当前安装结果不可复现，CI 或生产可能解析出不同版本。使用仓库指定包管理器重新生成锁文件并完成干净安装验证；若依赖变更非本次目标，则回滚 `package.json` 的对应依赖 hunk。

### 非阻断风险

Tag 尚未创建符合当前阶段预期，但创建和推送必须在修复后重新检查并单独确认。

### 是否允许发布

**否。** 存在敏感信息泄露和不可复现依赖两个阻断项，测试与构建通过不能覆盖这些风险。

### 发布前动作

修复两个阻断项，重新运行依赖安装、测试、构建和完整发布检查；通过后再请求创建 Tag。
