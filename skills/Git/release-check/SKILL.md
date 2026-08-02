---
name: release-check
description: "执行发布前非侵入式检查，核对 Git 状态、分支、Tag、版本号、未完成标记、FIXME、print、NSLog、console.log、debug 配置以及 Podfile、project.pbxproj、package.json 和锁文件变化，最终判断是否允许发布。用于 iOS、前端、Node 和 Spring 项目的发版门禁、Tag 前检查与发布风险报告。"
---

# 发布前检查

## 执行边界

只分析仓库，不修改工作区内容、版本号、本地分支或暂存内容，不生成 Tag、不提交、不推送、不安装依赖、不改构建配置。Git 状态类命令可能刷新 index 的 stat 元数据；显式 `fetch` 还会访问网络并更新远端跟踪引用与 `FETCH_HEAD`。把“允许发布”视为基于当前证据的门禁结论，不视为对部署、上架或推送 Tag 的授权。

先从宿主提供的当前 `SKILL.md` 路径进入其目录，并用物理路径解析符号链接，将结果记为 `SKILL_DIR`。下列 `../../../` 路径都相对 `SKILL_DIR` 解析；运行脚本前转换为绝对路径，不得相对目标 Git 仓库的当前目录直接执行。

先读取目标仓库根 `AGENTS.md`、项目发布文档和 CI 配置。使用以下资源：

- 对目标仓库运行 `../../../scripts/release_check.sh`，保留退出码和完整输出；脚本自身会定位目标仓库根目录。
- 结合 `../../../scripts/git_summary.sh`、`../../../scripts/git_branch.sh` 和 `../../../scripts/git_changed_files.sh` 核对 Git 证据。
- 读取 `../../../shared/rules/release-rule.md`、`../../../shared/rules/git.md` 和对应技术栈规则。
- 读取 `../../../shared/adapters/` 下与当前项目匹配的 Adapter。
- 采用 `../../../shared/templates/release_note.md` 与 `../../../shared/templates/risk_report.md` 组织结果。
- 按 `../../../shared/risk/critical.md`、`high.md`、`medium.md`、`low.md` 统一分级。

## 检查顺序

### 1. 确认仓库与工作区

运行：

```sh
git status --short --branch
git branch -vv
```

检查工作区、暂存区和全部未跟踪文件是否干净、当前分支是否有 upstream、是否领先或落后、是否 detached HEAD，以及是否存在未完成的 merge、rebase、cherry-pick 或 bisect。shallow clone 不能证明发布历史完整；submodule gitlink 必须逐个核对固定提交、URL、可取回性与子模块测试。发布内容必须能对应到一个明确提交。

### 2. 核对 Branch 与远端状态

运行 `git fetch origin` 前说明它会访问网络、可能调用 credential helper，并更新远端跟踪引用与 `FETCH_HEAD`，但不会自动改工作区内容或本地分支；用户禁止网络访问或命令失败时，将远端同步状态标为“未验证”。根据仓库实际发布策略判断当前 Branch 是否允许发版，不得假设所有项目都从 `main` 发布。

核对：

- 当前提交是否已包含目标发布分支要求的基线。
- 本地与 upstream 是否分叉。
- 分支保护或 CI 是否有尚未满足的条件。
- 发布候选是否来自可追踪分支，而非临时 detached 状态。

### 3. 扫描遗留标记与调试代码

使用根 `release_check.sh` 扫描候选提交 `HEAD` 中受版本控制的源文件；不得用可能受 `skip-worktree`、`assume-unchanged`、clean/smudge filter 或符号链接影响的工作树内容替代候选 Git blob。至少覆盖：

- 由 `TO` 与 `DO` 拼接形成的待办关键字。
- `FIXME`。
- `print`、`NSLog`、`console.log`、`console.debug`、`debugPrint`、`logger.debug` 与 `debugger;`。
- 明确启用的 `debug: true`、`export APP_DEBUG='true'`、`.xcconfig` / `.env*` 开关，以及 XML 或 binary plist 中 Boolean/string 形式的启用值；不得仅因出现 `Debug` 单词、`debug: false`、Xcode Debug Configuration 或 lockfile 包名就判为命中。plist 必须用结构化解析器读取，解析器缺失或结构损坏时保持未知，不得用标签正则静默放行。

排除 `.git/`、依赖缓存、构建产物和压缩文件。逐条结合语言与路径判断：测试中的日志、Python 业务输出和文档示例不自动等于发布阻断；生产代码中的敏感日志、调试分支、未完成关键逻辑或启用的 debug 配置按影响升级。报告文件、行号、命中内容类别和判断依据。

### 4. 检查依赖与工程文件

审查当前发布基线以来以下文件的变化：

- iOS：`Podfile`、`Podfile.lock`、`project.pbxproj`、`Package.swift`、`Package.resolved`。
- Node / 前端：`package.json`、`package-lock.json`、`pnpm-lock.yaml`，以及仓库实际使用的其他锁文件。
- Spring：`pom.xml`、Gradle 配置、依赖锁定或版本目录文件。

确认清单与锁文件在同一发布 scope 内同步、没有同时混用不兼容包管理器、依赖源和最低平台未被意外改变。Node 子包仅在候选 `HEAD` 的祖先 `package.json.workspaces` 明确匹配该相对路径时，才能使用最近祖先目录中的唯一锁文件；无法确认归属时 fail-closed。CocoaPods 与纯 SwiftPM 按目录核对，不能让兄弟工程的锁文件交叉抵消。锁文件被删除而对应 manifest 仍存在时必须阻断。`project.pbxproj` 重点检查签名、Bundle ID、Build Configuration、文件引用、Target Membership、版本字段和冲突残留。依赖或工程文件变化必须有可重复构建证据。

### 5. 核对版本号

从项目实际权威位置读取版本，不凭文件名猜测：

- 通用仓库：根级 `VERSION` 中的单一版本值。
- iOS：把公开版本 `MARKETING_VERSION` / `CFBundleShortVersionString` 与 build number `CURRENT_PROJECT_VERSION` / `CFBundleVersion` 分开核对。公开版本必须是三段纯数字，build number 是一至三段纯数字。标准变量引用只有在证据能对应到同一 project、target 与发布 configuration 时才能闭环；根脚本不会用仓库中其他 Xcode 工程的全局唯一值代替该关系。basename 精确为 `Info.plist` 的文件会直接进入候选；自定义 `*-Info.plist` 只有实际包含未注释的 Bundle 版本键时才进入静态核对，最终仍需 `INFOPLIST_FILE` / target 构建证据确认归属，不能凭后缀猜测。
- Node / 前端：用 `node` 解析候选 `HEAD` 中 `package.json` 的顶层 `version`，并核对应用内版本源；解析器缺失、JSON 非法或字段类型异常时不得用正则猜测。
- Spring：`pom.xml`、Gradle 或项目发布配置中的版本。

检查所有目标、扩展、产物与发布说明是否一致；检查公开版本相对上一个已发布版本是否按项目采用的语义版本规则递增。build number 必须符合一至三段数字格式；存在变量引用、多个值或无法确定发布 scope 时保留为未知证据，不把 build number 混入 Tag 或 Semantic Versioning 比较。需要闭环变量引用时，使用目标工程、目标 target/scheme 和 Release configuration 的 `xcodebuild -showBuildSettings` 输出或等价 CI 证据，不凭文件邻近关系猜测。读取 `../../../shared/references/semantic-version.md` 作为通用判断，项目自有版本规则优先。

### 6. 核对 Tag

运行：

```sh
git tag --points-at HEAD
git describe --tags --abbrev=0
git log -1 --format='%H %s'
```

检查计划 Tag 是否已存在、命名是否符合仓库规则、版本号是否一致、Tag 是否指向本次候选提交。没有计划创建 Tag 时明确记录，不自行创建。需要远端 Tag 证据但尚未 fetch 成功时标为未验证。

### 7. 核对构建与测试证据

从 README、CI 和项目配置选择最小发布验证，包括 lint、类型检查、单元测试、构建、归档或制品校验。只记录实际运行结果；需要账号、证书、设备、签名或外部服务的验证单独列为人工门禁。

## 判定规则

在报告中给出且只给出一个“是否允许发布”结论：

- **否**：存在 Critical/High 风险、工作区不干净、候选提交不明确、分支或 Tag 明确错误、版本不一致、关键构建/测试失败、依赖锁不一致或仍启用生产 debug 配置。
- **有条件允许**：无阻断项，但存在无法在当前环境验证的远端、签名、真机、账号、灰度或外部服务门禁；逐项写清发布前必须完成的动作。
- **是**：所有适用检查均完成且通过，没有未关闭的阻断项；列出证据范围和仍需常规监控的低风险事项。

未知状态不能自动视为通过。一般日志命中经上下文证明为安全后可降级，但必须保留审计记录。
自动化发布门禁必须把根脚本的任何非零退出视为失败，并保存普通 warning 报告；warning 只有关联到项目 build、test、签名等独立 required checks 后才能闭环。`--strict` 会把所有 warning 升级为阻断，只用于明确采用零 warning 政策的流水线，不能替代项目证据。

## 固定输出

按以下顺序输出：

1. **候选版本**：提交、Branch、版本号、Tag、检查基线。
2. **检查结果**：Git、遗留标记、调试代码、依赖/工程文件、版本、Tag、测试。
3. **阻断项**：按严重度列出证据、影响、建议操作和回滚建议。
4. **非阻断风险**：说明接受依据与监控方式。
5. **是否允许发布**：是、否或有条件允许，并给出一句明确理由。
6. **发布前动作**：仅列剩余门禁，不自动执行。

若用户要求创建 Tag、推送或部署，完成检查后仍需把该操作交给对应流程并取得独立确认。
