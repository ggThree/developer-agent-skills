# release-check

`release-check` 为通用、iOS、前端、Node 和 Spring 仓库提供证据化发布门禁。它可从根级 `VERSION` 或技术栈权威配置读取版本，并检查 Git 状态、Branch、Tag、调试残留、工程配置、依赖锁及测试记录，最终输出明确结论。

## 结论模型

- **是**：适用门禁都有通过证据。
- **否**：存在阻断风险或候选内容无法唯一确定。
- **有条件允许**：代码侧无阻断，但仍需真机、签名、账号或外部环境确认。

未知状态不会被自动当作通过。

根脚本在存在未知项时输出“有条件允许”并返回非零退出码，防止 CI 或 Agent 只看退出码就误判为通过；只有可解释的普通警告、且没有未知项或阻断项时，才以退出码 `0` 返回“有条件允许”。

无人值守 CI 必须拒绝脚本的任何非零退出、保存 warning 报告，并配置项目自己的 build/test required checks。`--strict` 会把所有 warning 升级为阻断，只适合零 warning 政策；默认模式的“有条件允许”也不能单独作为生产发布证据。

## 使用方式

```text
使用 $release-check 检查当前 iOS release 分支，计划版本为 3.8.0、Tag 为 v3.8.0；不执行发布写操作，若需 fetch 先说明网络与引用更新副作用。
```

Skill 复用根 `scripts/release_check.sh`，并结合 `shared/rules/release-rule.md`、技术栈 Adapter、风险定义和发布报告模板生成结果。它不会改版本、创建 Tag、提交、推送或部署。

脚本把候选提交 `HEAD` 作为源码、依赖和版本证据，阻断人工 `skip-worktree`、`assume-unchanged` 与版本/依赖文件符号链接造成的工作树掩盖；sparse-checkout、shallow clone 和未递归审计的 submodule gitlink 会被识别为未知证据，发布前需补齐完整 checkout、历史与子模块审计。Node 子包只有被候选 `HEAD` 中祖先 `package.json.workspaces` 明确覆盖时，才能复用其唯一锁文件；CocoaPods 与纯 SwiftPM 按目录核对清单和锁文件。解析 `package.json` 顶层字段需要目标环境提供 `node`，缺失时按未知证据 fail-closed。plist 由 Python 3 标准库 `plistlib` 结构化解析，兼容 XML 与 binary；解析器缺失或结构损坏时保持未知。iOS 的公开版本和 build number 分池处理，并识别带引号的 Xcode 数值标量；公开版本必须是三段纯数字，build number 是一至三段纯数字。标准变量引用只有在 project、target 与发布 configuration 的来源关系可证明时才能闭环；静态证据不足时返回未知并要求补充目标 `xcodebuild -showBuildSettings` 或等价 CI 证据。自定义 `*-Info.plist` 只有实际含 Bundle 版本键才进入静态核对，因此不会把不含这些键的 `GoogleService-Info.plist` 猜成版本来源。格式依据见 Apple 的 [CFBundleShortVersionString](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring) 与 [CFBundleVersion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion)。

阻断示例见 [examples/blocked-node-release.md](examples/blocked-node-release.md)。
