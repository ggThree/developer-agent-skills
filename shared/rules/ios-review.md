# iOS 代码审查规则

本规则覆盖 Objective-C、Swift、UIKit、SwiftUI、Xcode 工程与 CocoaPods/SPM 集成。先使用 [`../adapters/ios.md`](../adapters/ios.md) 和 [`../adapters/swift.md`](../adapters/swift.md) 识别项目，再结合 [`review-rule.md`](review-rule.md) 审查。

## 1. 工程与目标

- 确认 `.xcworkspace` 与 `.xcodeproj` 的真实入口，使用 CocoaPods 时优先 workspace。
- 核对变更所属 target、scheme 的 Build action、文件 Target Membership、Build Phases 与条件编译。
- 检查 `project.pbxproj` 是否出现重复 UUID、丢失引用、绝对路径、意外签名或配置漂移。
- 区分 App、Extension、Framework、Tests 的 Deployment Target、架构、Bundle ID 和权限。
- `Podfile`、`Podfile.lock`、`Package.swift` 与 `Package.resolved` 必须保持依赖声明和解析结果一致；依赖升级属于高风险变更，不能顺手执行。

## 2. 生命周期与导航

- 核对 `AppDelegate`、`SceneDelegate`、SwiftUI `App` 入口与多 Scene 行为。
- 检查冷启动、后台恢复、深链、Universal Link、通知点击和状态恢复是否进入正确路由。
- UIKit 中确认 ViewController 的创建、present/push/dismiss 配对及重复展示。
- SwiftUI 中检查 state 所有权、环境依赖、`task`/`onAppear` 重入和导航路径稳定性。

## 3. 线程与异步

- UI 更新必须在 Main Actor 或主线程；网络、解析和磁盘重任务不得阻塞主线程。
- Objective-C 检查 GCD queue、回调线程和同步锁；Swift 检查 `async/await`、Actor 隔离、Task 取消和 `Sendable` 边界。
- 回调、通知、KVO、Timer、CADisplayLink 和媒体 observer 必须成对解除。
- 检查竞态：重复点击、页面退出后的回调、多个请求覆盖新状态、任务取消后仍写 UI。

## 4. 内存与对象生命周期

- Block/closure 捕获 `self` 是否形成环；弱引用后对象消失是否仍有安全分支。
- Delegate 的强弱语义是否正确；Notification/KVO 的注册与注销是否匹配系统版本。
- Core Foundation、C/C++、音视频缓冲和 Objective-C bridging 的所有权是否清晰。
- 图片、视频、WebView、大列表与缓存是否有上限，是否在内存警告或离屏时释放。

## 5. UI、布局与可访问性

- Safe Area、横竖屏、分屏、动态字体、深色模式、键盘和不同屏幕尺寸。
- Auto Layout 约束是否冲突或欠约束；异步高度变化是否触发布局更新。
- 点击区域、VoiceOver label/hint、颜色对比度和 Reduce Motion。
- 不以固定状态栏高度、机型名称或私有 API 推测设备布局。

## 6. 权限、安全与隐私

- `Info.plist` usage description 与实际 API 匹配，并检查拒绝、受限和稍后授权路径。
- Keychain、文件保护、剪贴板、相册、定位、相机与麦克风遵循最小权限。
- 禁止放宽全局 ATS、绕过证书校验或无条件接受 trust challenge。
- 日志、崩溃报告、埋点和 URL 不得包含 token、密码、完整身份证件或支付凭证。
- Privacy Manifest、Required Reason API 与第三方 SDK 声明保持一致。

## 7. 网络、数据与兼容性

- 请求字段、响应模型、空值、日期、精度、状态码和错误映射与服务端契约一致。
- URL 拼接使用组件化 API；深链需验证 scheme、host、path 和 query，不做宽泛字符串替换。
- Core Data/SQLite/UserDefaults/Keychain 变化需要迁移与降级策略。
- 检查最低 iOS 版本、API availability、Objective-C nullability 与 Swift bridging。
- 真机专属能力（推送、相机、蓝牙、支付、证书、后台模式）不能只用 Simulator 结论覆盖。

## 8. 最小验证

优先使用仓库现有 scheme 与 CI 命令：

1. 目标 scheme 的干净增量构建；
2. 受影响单元测试或 UI 测试；
3. 静态分析与编译 warning 核对；
4. 关键入口的 Simulator 回归；
5. 涉及设备能力时列出真机、账号和环境验证边界。

构建命令必须显式写 workspace/project、scheme、configuration 和 destination，防止构建错误 target。

## 9. 高风险信号

- 签名、证书、Entitlements、Capabilities 或生产 Bundle ID 变化；
- ATS/trust、Keychain access group、支付、推送、后台任务变化；
- `project.pbxproj` 大范围重写或第三方二进制升级；
- 数据模型迁移、线程隔离变化、跨语言内存所有权变化；
- App/Scene 生命周期入口切换。

这些变化至少按 [`../risk/high.md`](../risk/high.md) 评估，满足不可恢复或大范围安全后果时升级为 [`../risk/critical.md`](../risk/critical.md)。
