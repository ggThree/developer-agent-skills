# Swift 项目 Adapter

## 这是哪种项目

本 Adapter 面向以 Swift 编写的 Apple 平台应用、Swift Package、命令行工具或服务端程序。它描述语言与并发模型检查；若 target 为 iOS，还要叠加 [`ios.md`](ios.md)。

## 如何识别

- 存在 `.swift` 文件；
- 存在 `Package.swift`，或 Xcode target 的 `SWIFT_VERSION` 已配置；
- `Package.resolved`、`.swiftpm`、Tests target 或 CI 使用 `swift build`/`swift test`；
- 代码使用 SwiftUI、UIKit/AppKit、Foundation、Vapor 等 Swift API。

识别后继续确认运行平台、Swift tools version、最低系统版本、编译模式和是否启用 Strict Concurrency；这些条件会改变诊断结论。

## 应该检查什么

### 类型与 API 设计

- Optional 的来源、解包和 fallback 是否保留真实错误语义。
- `Codable` 的字段名、默认值、枚举未知值、日期与数字精度。
- 值语义与引用语义是否符合共享状态需求；Copy-on-Write 是否被误解。
- access control、protocol、generic constraint 和 existential 的兼容性。
- public API 变化是否破坏调用方或二进制/Source compatibility。

### Concurrency

- `async/await`、Task、TaskGroup 的取消、优先级和错误传播。
- `@MainActor`/自定义 Actor 的隔离边界，跨 Actor 数据是否 `Sendable`。
- `Task.detached` 是否丢失 Actor、Task Local 与取消关系。
- continuation 是否恰好 resume 一次，callback bridge 是否处理取消。
- 同一资源是否被多个 Task、GCD queue 或 legacy callback 竞态访问。

### 生命周期与内存

- closure 捕获 `self` 的所有权；`weak self` 后对象为空时行为是否安全。
- Delegate、publisher、AsyncSequence、Notification 和 Timer 的取消/释放。
- Objective-C bridging、`Unmanaged`、Core Foundation 与 unsafe pointer 的所有权。
- 长生命周期 Task 是否保留 ViewModel、Controller 或服务对象。

### 错误与可测试性

- `throws`、Result 和 optional 是否区分业务无结果与系统失败。
- 不用空 `catch`、`try?` 或强制操作隐藏可恢复错误。
- 依赖注入边界允许稳定测试时间、网络、存储和并发行为。
- 测试异步完成、取消与 Actor hop，不依赖固定 sleep 规避竞态。

## 应该忽略什么

- 不把所有 force unwrap 自动判为缺陷；只在输入或生命周期无法证明时报告。
- 不为追求语法新颖而改写稳定 Objective-C/UIKit 接口。
- 不建议无依据升级 Swift tools version、开启全局 Strict Concurrency 或迁移 Observation。
- 不审查自动生成的 Swift 文件，除非生成规则或提交产物本身发生变化。
- 不把编译器 warning 当作可忽略噪声，也不在未确认工具链时断言某语法不可用。
- 不把微小 `map`/loop 风格差异包装成性能问题，性能结论需要测量。

## 高风险是什么

- Actor 隔离被 `nonisolated(unsafe)`、unchecked `Sendable` 或不安全指针绕过；
- continuation 多次或永不 resume，导致崩溃或永久挂起；
- public API、序列化模型或持久化 enum 的破坏性变化；
- 大范围 Swift language mode/Strict Concurrency 升级；
- closure/Task 形成长期 retain cycle，或桥接所有权导致 use-after-free；
- 安全、支付、认证路径使用强制解包或静默错误 fallback。

按影响参考 [`../risk/high.md`](../risk/high.md) 与 [`../risk/critical.md`](../risk/critical.md)。

## 最小验证

- Swift Package 使用仓库固定工具链执行 `swift build` 和相关 `swift test`。
- Xcode 项目使用真实 scheme，并记录 Xcode/Swift 版本与 destination。
- 并发改动开启相关 diagnostics，运行取消、重复进入与失败路径测试。
- public API 变化检查所有调用方；Codable 变化使用旧数据样本验证解码兼容。
