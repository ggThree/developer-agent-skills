# 更新日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的组织方式，并使用 [Semantic Versioning](https://semver.org/lang/zh-CN/) 管理版本。

## [0.1.0] - 发布候选

### 新增

- 提供 `safe-git-workflow`、`review-diff`、`commit-message`、`release-check`、`merge-helper`、`rollback-helper` 六个可直接使用的 Git Skills。
- 提供九个兼容 macOS 与 Linux 的仓库检查脚本，以及统一的 Shell 公共库。
- 提供 Objective-C、Swift、Vue、React、uni-app、Spring Boot、Node.js 七类项目 Adapter。
- 提供提交、审查、风险、发布、合并与回滚报告模板。
- 提供四级风险模型、六类工程规则和五份 Git 参考资料。
- 提供 Codex、ChatGPT、Claude Code、Cursor 的安装与使用说明。
- 提供 GitHub Actions、Issue 模板、Pull Request 模板、安全策略和贡献规范。
- 提供 54 项临时仓库驱动的安全集成测试，覆盖提交与发布路径、首次发布完整树、版本降级阻断、iOS 公开版本与 build number、Xcode 多工程 scope 与精确 Build Setting 键、XML/二进制 plist、诊断扫描自检与误报边界，以及既有依赖 scope、Git 状态和 fail-closed 路径。

### 修复

- 收窄 `release_check.sh` 的 debug 识别规则，避免把 Xcode Debug Configuration、`debug: false` 和 Node lockfile 依赖误判为调试残留，同时保留真实诊断调用与启用型配置证据。
- 分开核对 iOS 公开版本与 build number，识别带引号的 Xcode 标量与标准变量引用，排除注释伪值并按 Apple 字段格式阻断无效值；变量引用、缺失值或多发布 scope 在无法证明 target/configuration 来源时返回不可自动放行的未知结论。
- 识别 `.xcconfig`、含 `export` / 引号的 `.env*` 与结构化 plist 中明确启用的 debug 配置；XML 与 binary plist 统一使用 `plistlib`，解析器缺失或结构损坏时保持未知，扫描器实现和测试夹具不再触发自身规则。
- 自定义 `*-Info.plist` 只有实际含未注释的 Bundle 版本键才进入静态核对，避免 `GoogleService-Info.plist` 等第三方配置制造伪未知项，同时保留自定义 Bundle plist 的版本差异检查。
- 在目标与源引用相同的提前返回之前检查进行中的 merge、rebase、cherry-pick 与 revert，避免合并预检 fail-open。
- 修正发布候选安装说明、Git 2.38 完整能力边界和项目级绝对符号链接的团队使用风险。
- 修正 CI 对 `--strict` 的适用边界：任何非零退出都必须失败，普通 warning 由独立 required checks 闭环，零 warning 流水线才升级全部 warning。
