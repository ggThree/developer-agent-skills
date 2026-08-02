# FAQ

## 这是 Git 命令封装吗？

不是。脚本只负责稳定采集事实，Skill 负责分析、风险分级、确认和输出。危险操作不会因为调用 Skill 而自动获得授权。

## 为什么安装时要保留整个仓库？

每个 Skill 会复用 `scripts/` 和 `shared/`。只复制 `SKILL.md` 会丢失确定性检查器、Adapter、风险模型和模板，也会造成版本漂移。

## 为什么使用符号链接？

符号链接让多个宿主共享同一份经过版本控制的 Skill，同时保留仓库拓扑。创建前检查目标是否已存在；不要使用强制覆盖参数替换未知文件。

用户级链接适合单机使用。项目级示例若指向本机绝对路径，不得提交给团队或 CI；团队共享应固定完整仓库版本并使用仓库内相对链接，否则其他机器无法访问根级 `scripts/` 与 `shared/`。

## Skill 没有触发怎么办？

1. 检查目录是否为 `<skills-root>/<skill-name>/SKILL.md`；
2. 检查目录名与 frontmatter 的 `name` 是否一致；
3. 检查 YAML 分隔符和 description；
4. 使用宿主的 Skills 列表或显式调用；
5. 首次创建发现目录后重启宿主；
6. 检查宿主版本和 Skill 可见性设置。

## `git fetch origin` 会改代码吗？

不会改工作区文件，但会更新本地的远端跟踪引用，并可能触发凭据或网络访问。安全工作流会在核对 remote 后把 fetch 作为证据刷新步骤；用户明确禁止网络访问时跳过并标记远端状态未知。`branch_sync.sh` 为了保持纯离线和只读，只比较本地已有引用，并明确提示结果可能过期。fetch 成功也不表示允许 merge、rebase 或 push。

## 工作区有未提交修改还能审查吗？

可以，且这正是 `review-diff` 的主要场景。执行暂存、切分提交、切换分支或回滚前，应先识别这些修改属于谁、是否完整、是否含未跟踪文件。

## 为什么 `git reset --hard` 被禁止？

它可能同时覆盖索引和工作区，未提交内容难以恢复。项目优先使用 `restore` 撤销局部工作区变更、`revert` 撤销共享提交，或在严格条件下分析 `reset --soft` / `--mixed`。

## “允许发布”是否代表可以部署生产？

不是。它只表示本仓库定义的静态门禁没有发现阻断项。生产发布仍需项目 CI、制品签名、数据库兼容、设备/浏览器回归、变更审批和观测方案。

`release_check.sh` 默认模式在 blocker 或 unknown 存在时返回非零，只有普通 warning 时可能以退出码 `0` 返回“有条件允许”。CI 必须把任何非零退出视为失败、保存 warning 报告，并把项目原生构建与测试设为独立 required checks。只有采用“零 warning”政策且不会与版本工程文件的正常变化冲突时，才使用 `--strict` 把所有 warning 一并升级为阻断。

## 为什么完整功能要求 Git 2.38？

基础状态与 Diff 脚本可在 Git 2.30 至 2.37 工作，但可靠、隔离的冲突预演依赖现代 `git merge-tree --write-tree`。旧版本缺少该能力时，`merge_check.sh` 会按 fail-closed 返回非零，不会用旧三参数模式给出安全结论。

## 为什么 pnpm monorepo 可能无法自动确认 lock scope？

当前脚本只在候选 `HEAD` 的祖先 `package.json.workspaces` 明确匹配子包路径时复用祖先锁文件；仅通过 `pnpm-workspace.yaml` 声明的 Workspace 会保守地返回非零，避免把无关根锁误认为子项目证据。这是当前静态解析边界，不应通过忽略退出码绕过；可按项目规则补充适配，并用“已声明 Workspace / 未声明嵌套项目”两类夹具验证后再采用。

## 为什么 `Podfile` 或 `Package.swift` 改动可能要求锁文件也变化？

二者都是可执行 DSL，通用静态脚本无法可靠证明某次文本变化完全不影响依赖解析。当前门禁选择保守策略：已有同目录 lock 时，manifest 单独变化会阻断；不要为了通过检查制造虚假 lock Diff。应先运行项目原生 resolve/build/test，记录 lock 确实不变的证据，再由项目维护者决定是否为该仓库实现更精确的语义适配。

## Commit Message 为什么默认中文？

这是本仓库的统一协作规范。`commit-message` 同时支持英文，并保留 `type(scope): subject` 等 Conventional Commit 关键结构，便于自动化工具解析。

## 支持 Windows 吗？

Skill 文档本身可被支持 Agent Skills 的 Windows 宿主读取，但当前 Shell 检查器的正式兼容范围是 macOS 与 Linux。Windows 用户可在 WSL 中运行脚本；原生 PowerShell 适配需要独立实现和验证。

## 可以在生产仓库直接使用吗？

可以用于只读分析，但应先审查 Skill 与脚本、锁定可信版本、使用最小权限凭据，并在测试仓库验证。任何写操作仍由操作者和仓库保护策略共同把关。
