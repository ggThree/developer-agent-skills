---
name: commit-message
description: "根据 Git 暂存差异生成准确的中文或英文 Commit Message，支持 Conventional Commit 与 Gitmoji，并在 feat、fix、docs、refactor、perf、test、style、build、ci 九类中自动判定。用于提交前命名、提交拆分判断、双语提交信息转换和提交规范检查。"
---

# Commit Message 生成

## 基本原则

只描述证据中真实存在的修改，不编造动机、工单、测试结果、兼容性或破坏性变更。默认读取暂存区并输出中文 Conventional Commit；仅在用户明确要求时切换英文、Gitmoji 或组合格式。

先从宿主提供的当前 `SKILL.md` 路径进入其目录，并用物理路径解析符号链接，将结果记为 `SKILL_DIR`。下列 `../../../` 与 `../` 路径都相对 `SKILL_DIR` 解析；运行脚本前转换为绝对路径，不得相对目标 Git 仓库的当前目录直接执行。

读取目标仓库根 `AGENTS.md` 以及已有提交约定。使用以下资源：

- 运行 `../../../scripts/git_commit_check.sh` 检查暂存内容、敏感信息与提交前条件；该脚本不校验 Commit Message 文本。
- 读取 `../../../shared/references/conventional-commit.md` 和 `../../../shared/references/git-best-practice.md`。
- 中文输出采用 `../../../shared/templates/commit_cn.md`，英文输出采用 `../../../shared/templates/commit_en.md`。
- 需要确认变更意图时读取 `../review-diff/SKILL.md`，不得反向猜测未读取的代码。

## 收集证据

先运行：

```sh
git status --short
git diff --cached --stat
git diff --cached
```

暂存区为空时明确说明“当前没有可生成正式提交信息的暂存差异”。用户只想预览未暂存修改时可读取 `git diff`，但必须把结果标记为“预览候选”，避免暗示它对应最终提交。

必要时运行 `git log -10 --pretty=format:'%s'` 识别仓库已有语言、scope 和标题风格。仓库明确规范优先于默认值，但不得继承明显不安全或不一致的历史写法。

## 判定提交类型

从以下九类中选择最能描述主要目的的一类：

| Type | 使用条件 | 不要误用 |
| --- | --- | --- |
| `feat` | 增加用户或调用方可感知的新能力 | 不用于内部整理或单纯依赖升级 |
| `fix` | 修复错误行为、崩溃、兼容性或安全缺陷 | 不用于尚未证明的“可能修复” |
| `docs` | 只修改文档、注释或说明 | 代码行为同时变化时不要使用 |
| `refactor` | 重组实现且不改变外部行为 | 行为修复应使用 `fix` |
| `perf` | 以可验证的性能改善为主要目的 | 没有性能证据时不要使用 |
| `test` | 只增加或调整测试及测试夹具 | 生产代码变化时按主要行为分类 |
| `style` | 只调整格式、空白或无行为影响的样式 | UI 样式行为变化可能属于 `fix` 或 `feat` |
| `build` | 构建系统、依赖、打包或编译配置变化 | CI 流水线专用改动使用 `ci` |
| `ci` | CI 工作流、流水线脚本或自动化配置变化 | 本地构建脚本通常使用 `build` |

一个暂存区包含多个彼此独立目的时，不要选择模糊 type；建议按路径或 hunk 拆分，并为每个原子提交分别生成信息。

## 推导 Scope

优先从稳定模块、包、Feature 或子系统名称提取短小 scope，例如 `auth`、`payment`、`ios`、`api`。仅有跨仓库基础设施变更或无法可靠归属时省略 scope。不要把文件名、人员名或临时分支名机械地当作 scope。

## 编写标题

采用以下结构：

```text
<type>(<scope>): <subject>
```

没有可靠 scope 时使用 `<type>: <subject>`。标题保持单行、具体、可检索，不以句号结尾。中文默认使用清晰动宾结构；英文使用祈使语气和小写开头。避免“更新代码”“修复问题”“调整逻辑”等无法说明行为的表述。

## 补充正文与 Footer

简单原子变更只输出标题。以下场景补充正文：

- 需要解释“为什么”而非复述 diff。
- 存在迁移步骤、兼容边界或非显然取舍。
- 同一目的涉及多个关键行为变化。

只有 diff 明确证明破坏性变更时才添加 `!` 或 `BREAKING CHANGE:`，并说明受影响接口和迁移方式。只有证据提供真实 issue 编号时才添加 `Refs:`、`Closes:` 等 Footer。

## 语言模式

### 中文 Conventional Commit

默认输出：

```text
fix(auth): 避免令牌刷新请求重复执行
```

### 英文 Conventional Commit

用户要求英文时输出：

```text
fix(auth): prevent duplicate token refresh requests
```

### Gitmoji

用户要求 Gitmoji 时，在 Conventional 标题前添加与 type 对应的 emoji：

| Type | Gitmoji |
| --- | --- |
| `feat` | ✨ |
| `fix` | 🐛 |
| `docs` | 📝 |
| `refactor` | ♻️ |
| `perf` | ⚡️ |
| `test` | ✅ |
| `style` | 🎨 |
| `build` | 📦️ |
| `ci` | 👷 |

组合格式示例：

```text
🐛 fix(auth): 避免令牌刷新请求重复执行
```

## 输出格式

依次输出：

1. **范围判断**：暂存区文件和是否适合单一提交。
2. **类型判断**：type、scope 及简短依据。
3. **推荐版本**：一个可直接使用的完整 Commit Message。
4. **可选版本**：只提供用户要求的语言或 Gitmoji 变体。
5. **拆分建议**：仅在存在独立目的时列出，每项附对应文件范围。
6. **校验结果**：报告 `git_commit_check.sh` 的实际结果或未运行原因。

只生成信息时不得执行 `git add` 或 `git commit`。用户要求提交时转用 `../safe-git-workflow/SKILL.md`，在展示暂存区和完整信息后等待独立确认。
