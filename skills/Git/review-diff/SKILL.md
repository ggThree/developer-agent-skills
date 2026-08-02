---
name: review-diff
description: "审查 Git 工作区、暂存区、提交或分支差异，自动识别 Objective-C、Swift、Vue、React、Spring 技术栈并输出修改摘要、修改原因、影响范围、风险分析、建议测试和建议 Commit Message。用于代码评审、提交前检查、PR 风险审查和跨栈变更分析。"
---

# 跨栈 Diff 审查

## 审查原则

先确定比较范围，再读取完整 diff 和必要上下文。把用户描述当作待验证假设；以代码、类型、配置、测试和调用链为证据。只审查，不修改文件、不暂存、不提交。

先从宿主提供的当前 `SKILL.md` 路径进入其目录，并用物理路径解析符号链接，将结果记为 `SKILL_DIR`。下列 `../../../` 与 `../` 路径都相对 `SKILL_DIR` 解析；运行脚本前转换为绝对路径，不得相对目标 Git 仓库的当前目录直接执行。

优先读取目标仓库根 `AGENTS.md` 和项目级规范。使用以下资源：

- 运行 `../../../scripts/git_summary.sh`、`../../../scripts/git_diff_summary.sh` 和 `../../../scripts/git_changed_files.sh` 获取范围。
- 读取 `../../../shared/rules/review-rule.md` 和技术栈对应规则。
- 读取 `../../../shared/risk/critical.md`、`high.md`、`medium.md`、`low.md` 统一风险分级。
- 输出可复用报告时采用 `../../../shared/templates/review_report.md` 和 `../../../shared/templates/risk_report.md`。
- 生成提交建议时遵循 `../commit-message/SKILL.md`。

## 确定审查范围

根据用户目标选择一种范围并在报告开头写明：

```sh
# 未暂存改动
git diff --stat
git diff

# 已暂存改动
git diff --cached --stat
git diff --cached

# 单个提交
git show --stat --format=fuller <commit>
git show --format=fuller <commit>

# 两个引用或分支共同祖先以来的变化
git diff --stat <base>...<head>
git diff <base>...<head>
```

不得默认把未暂存和已暂存差异合并。用户未指定范围时，先运行 `git status --short --branch`，分别报告存在的范围，并优先审查当前未提交差异。引用不明确或命令失败时说明边界，不猜测内容。

## 自动识别技术栈

结合变更文件、构建配置和邻近源文件识别；一个 diff 可同时使用多个 Adapter。

| 证据 | 技术栈 | 必读资料 | 审查重点 |
| --- | --- | --- | --- |
| `.h`、`.m`、`.mm`、`.xcodeproj`、`Podfile` | Objective-C / iOS | `../../../shared/adapters/ios.md`、`../../../shared/rules/ios-review.md` | 生命周期、线程、空值、内存、权限、Target Membership、设备差异 |
| `.swift`、`Package.swift` | Swift / iOS | `../../../shared/adapters/swift.md`、`../../../shared/rules/ios-review.md` | Actor 隔离、Sendable、可选值、任务取消、主线程、API availability |
| `.vue`、`vite.config.*`、`uni.scss` | Vue / uni-app | `../../../shared/adapters/vue.md`；出现 uni-app 配置时加读 `../../../shared/adapters/uniapp.md` | 响应式状态、生命周期、watch 依赖、路由缓存、表单与多端条件编译 |
| `.tsx`、`.jsx`、React 依赖 | React | `../../../shared/adapters/react.md`、`../../../shared/rules/frontend-review.md` | Hook 依赖、状态闭包、key、并发更新、卸载后异步更新、可访问性 |
| `pom.xml`、`build.gradle*`、Spring 注解、`.java` | Spring Boot | `../../../shared/adapters/spring.md`、`../../../shared/rules/backend-review.md` | 入参校验、鉴权、事务、SQL、空值、并发、日志、错误与接口兼容 |

出现 Node 工具链或服务端 JavaScript 时读取 `../../../shared/adapters/node.md`。不要仅凭文件扩展名下结论；例如 `.h` 可能属于 C 库，应结合工程配置确认。无法识别时使用通用规则并明确不确定性。

## 审查步骤

### 1. 建立变更意图

从用户说明、提交信息、测试名称和代码上下文推断修改目的。将“代码明确表现的事实”和“对业务目的的推断”分开。缺少需求时不要编造修改原因。

### 2. 追踪行为链

读取被改符号的定义、调用者、类型、接口契约、持久化模型、配置和现有测试。检查新增分支是否都有输入来源与输出处理，删除逻辑是否仍被其他路径依赖。

### 3. 按技术栈检查

套用已识别 Adapter，只报告 diff 引入或暴露且可由证据支持的问题。重点检查：

- 正确性：条件边界、错误分支、空值、状态同步、序列化与字段类型。
- 安全性：鉴权、敏感数据、注入、证书校验、权限扩大和危险配置。
- 数据与兼容性：API、数据库、持久化格式、公开接口、平台与最低版本。
- 运行时：线程、生命周期、资源释放、重复请求、事务和并发竞态。
- 可维护性：重复逻辑、隐式契约、不可观测失败和缺少必要测试。

### 4. 分级风险

按共享风险定义标记 `Critical`、`High`、`Medium`、`Low`。每条风险必须包含：

1. 风险名称与等级。
2. 精确文件和行号或 diff hunk。
3. 触发条件。
4. 可观察影响。
5. 判断依据。
6. 最小修复或验证建议。
7. 回滚建议。

没有可证实缺陷时明确写“未发现阻断性问题”，但仍列出验证边界。不要用代码风格偏好冒充功能风险，不要把历史遗留问题错误归因于当前 diff。

### 5. 设计验证

优先使用项目已有脚本、测试配置和 CI 命令。区分“已实际运行”“建议运行”和“需要真机、真实账号或外部环境验证”。不得把编译通过写成运行时场景已通过。

### 6. 生成提交建议

只根据审查范围生成 Commit Message。混合多个独立目的时建议拆分提交；不得用一个宽泛标题掩盖无关改动。

## 固定输出格式

始终按以下六个一级小节输出，标题和顺序不得缺失：

### 修改摘要

列出审查范围、识别出的技术栈、关键文件和可观察行为变化。

### 修改原因

说明代码直接证明的原因；把需求推断和未知信息明确标注。

### 影响范围

覆盖模块、调用者、接口、数据、平台、构建与发布影响。指出未受影响的边界，避免夸大。

### 风险分析

先列可执行 findings，按严重度降序排列；每条附精确证据。再列非阻断风险和验证边界。

### 建议测试

按最小单元测试、集成测试、构建检查、手工或设备回归排序，提供项目真实可用的命令或步骤。

### 建议 Commit Message

默认给出一个中文 Conventional Commit；必要时给出拆分方案。只在用户要求时追加英文或 Gitmoji 版本。

## 审查边界

不要因为用户要求“review”而执行修复、格式化、依赖升级或任何 Git 写操作。若 diff 太大，先给出文件级风险地图，再分批读取完整差异；不得仅凭 `--stat` 宣称审查完成。
