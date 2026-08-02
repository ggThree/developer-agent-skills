# iOS 项目 Adapter

## 这是哪种项目

本 Adapter 面向 Apple 平台客户端工程，重点覆盖 iOS/iPadOS 的 App、Extension、Framework 与 Tests。项目可能使用 Objective-C、Swift、UIKit 或 SwiftUI，并通过 Xcode、CocoaPods 或 Swift Package Manager 构建。

## 如何识别

以下证据组合可识别 iOS 工程：

- 存在 `.xcodeproj` 或 `.xcworkspace`；
- 存在 `project.pbxproj`、`Info.plist`、`.entitlements` 或 `PrivacyInfo.xcprivacy`；
- 存在 `.m`、`.mm`、`.h` 或 `.swift` 源文件；
- `Podfile`、`Podfile.lock`、`Package.swift` 或 `Package.resolved` 引用 Apple 平台依赖；
- CI 使用 `xcodebuild`，并包含 iOS Simulator、generic iOS device 或 archive destination。

只出现 `.swift` 不能单独证明是 iOS 项目，也可能是 macOS 或服务端 Swift；应以 target 的 `SDKROOT`、platform 和 scheme 为准。

## 应该检查什么

### 工程入口与构建

- 优先读取仓库的 `AGENTS.md`、README、CI 和 Fastlane 配置确定 workspace/project、scheme 与 configuration。
- 使用 CocoaPods 时确认从 `.xcworkspace` 构建；检查 Podfile 与 lockfile 是否同步。
- 核对改动文件的 Target Membership、Build Phases、资源 Copy 阶段和条件编译。
- 审查 `project.pbxproj` 的签名、Deployment Target、架构、搜索路径和重复引用。
- 区分 App、Widget、Notification/Share Extension 与 Tests 的配置差异。

### 生命周期与运行行为

- `AppDelegate`、`SceneDelegate`、SwiftUI `App` 入口和多 Window/Scene。
- 冷启动、后台恢复、前后台切换、深链、Universal Link、通知点击。
- UI 工作是否在主线程；异步任务能否取消；页面离开后是否仍写 UI。
- Delegate、Notification、KVO、Timer、媒体 observer 和 closure 的生命周期。
- Safe Area、键盘、旋转、动态字体、深色模式和 VoiceOver。

### 权限、安全与数据

- `Info.plist` 权限描述、授权拒绝路径和真实能力调用是否一致。
- ATS、TLS、server trust、Keychain access group、文件保护和敏感日志。
- Entitlements、Capabilities、Bundle ID、Associated Domains、Push 与后台模式。
- Core Data/SQLite/UserDefaults/Keychain 的 Schema、迁移和降级兼容。
- API 字段、nullability、日期、状态码和错误映射与服务端契约。

### Objective-C 专项

- nullable/nonnull、轻量泛型、selector、KVC/KVO 和 category 冲突。
- Block retain cycle、delegate 属性语义、Core Foundation bridging 与 C 指针边界。
- 宏、预编译头、module import 和 `.m`/`.mm` 编译差异。

Swift 代码还需加载 [`swift.md`](swift.md)。完整审查规则见 [`../rules/ios-review.md`](../rules/ios-review.md)。

## 应该忽略什么

- 不审查 DerivedData、Pods 构建产物、`.xcarchive`、符号文件和生成代码，除非它们被错误提交或正是目标产物。
- 不把 Xcode 自动排序、UUID 顺序或无行为影响的工程文件噪声当作缺陷。
- 不要求为了“现代化”把 Objective-C 全量迁移到 Swift，或把 UIKit 全量改成 SwiftUI。
- 不默认升级 Pods、Swift tools version、Deployment Target 或 Xcode 推荐设置。
- 不用 Simulator 失败直接推断真机失败，也不用 Simulator 成功覆盖真机专属验证。
- 不修改签名、证书、Profile、Capabilities 和生产 Bundle ID，除非任务明确授权并完成高风险确认。

## 高风险是什么

- 正式环境关闭证书验证、扩大 ATS 例外或记录 token/支付凭证；
- 修改签名、Entitlements、Keychain group、Push、Associated Domains 或后台能力；
- `project.pbxproj` 大面积重写、target/scheme 错配、依赖大版本升级；
- 支付、登录、深链、数据迁移、并发与跨语言内存所有权变化；
- 只验证错误 target、错误 scheme 或 Simulator，却宣称正式设备可用。

以上通常按 [`../risk/high.md`](../risk/high.md) 处理；大范围凭证泄漏、越权或不可恢复数据破坏按 [`../risk/critical.md`](../risk/critical.md) 处理。

## 最小验证

1. 列出 schemes 与目标配置，确认真实构建入口。
2. 对受影响 scheme 执行最小 `xcodebuild build` 或仓库已有脚本。
3. 运行相关单元测试/UI 测试并记录 destination。
4. 用 Simulator 回归可模拟路径；涉及相机、推送、支付、蓝牙、证书或后台能力时列出真机清单。
5. 审查构建 warning、运行日志与目标 Diff；构建成功不替代业务回归。
