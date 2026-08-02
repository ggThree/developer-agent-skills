# 测试

`integration.sh` 使用临时 Git 仓库执行 54 项安全门禁验证，不访问网络，也不改动开发者仓库。覆盖脚本帮助与可执行位、正常提交与完整变更清单、暂存秘密脱敏、特殊路径、首次发布完整树、发布未知态、Semantic Versioning 递增与降级阻断、iOS 公开版本与 build number、Xcode 多工程 scope 与精确 Build Setting 键、XML/二进制 plist、诊断扫描自检与误报边界、候选 `HEAD`、隐藏 index/未跟踪文件、严格比较基线、顶层 JSON 版本、Node Workspace/CocoaPods/SwiftPM 依赖 scope、锁文件删除/改名、shallow clone、submodule gitlink、进行中 Git 操作、冲突及无冲突隔离预演、禁止 hard reset、符号链接防劫持和损坏 index 的 fail-closed 行为。

完整测试需要 Git、Node.js 与 Python 3；Shell 脚本本身在解析器缺失时会返回未知或阻断，不会用文本正则降级放行。

运行：

```sh
./tests/integration.sh
```

测试兼容 macOS `/bin/sh`、Bash 3.2 和 Linux Dash。所有夹具位于权限收紧的 `mktemp -d` 目录，退出或收到信号后只清理该精确目录。
