# 维护者发布流程

本流程用于发布 `developer-agent-skills` 的可审计版本。发布必须从受保护的 `main` 分支产生，稳定安装只指向已经验证的 Tag。任何 `commit`、Tag 创建、`push` 和 GitHub Release 发布都分别确认，不把一次授权复用于后续操作。

## 首次仓库引导

空仓库没有可运行 CI 的默认分支，也无法先把 required checks 设为有效门禁。首次发布必须先完成一次不含 Tag 的 bootstrap：

1. 在本地完成本文的质量验证与[提交检查点](#提交检查点)，形成首个发布候选提交；
2. 确认远端仍为 `ggThree/developer-agent-skills`、没有意外初始提交，并逐项检查待推送提交；
3. 单独确认后首次推送 `main`，不同时推送 Tag；
4. 等待 `Shell、Skill 与文档` 和 `macOS Shell 兼容性` 两个 Job 全部成功；
5. 为 `main` 配置 ruleset 或 branch protection：禁止 force push 和删除，后续变更要求 Pull Request，并把两个质量 Job 设为 required checks；
6. 单维护者阶段不启用“必须 Code Owner 批准”，避免唯一维护者自我阻塞；有第二位可信维护者后再启用独立审批。若平台支持，禁止管理员绕过上述质量门禁；
7. 完成保护规则后，才进入 `v0.1.0` Tag 和 GitHub Release 阶段。

首次推送前使用：

```bash
git remote -v
git status --short --branch
git log -1 --oneline --decorate
git push -u origin main
```

首次 `push` 是独立远端操作，必须在执行前确认。bootstrap 不创建 Tag、不创建 Release，也不把首次 CI 结果视为后续版本可以绕过 Pull Request 的授权。

## 发布前条件

- GitHub canonical repository 为 `https://github.com/ggThree/developer-agent-skills`；
- `main` 已完成首次 bootstrap，并启用与当前维护模式匹配的保护规则；
- 本地 `main` 已明确执行 `git fetch origin`，并与 `origin/main` 对齐；
- 工作区、暂存区和未跟踪文件已经逐项审查；
- `VERSION`、`CHANGELOG.md`、`shared/scripts/lib.sh` 与 `SECURITY.md` 的版本范围一致；
- README 与安装文档已经从“发布候选”切换为本次计划创建的固定 Tag 安装命令，`CHANGELOG.md` 已写入发布日期和对应 Release 链接，质量工作流同步校验稳定版文案；Tag 创建后还要再次验证这些链接真实可用；
- Ubuntu 与 macOS 质量检查均通过；
- 没有真实凭据、证书、私钥、生产数据或未脱敏日志进入 Git 历史。

## 本地取证

以下命令不创建提交、Tag 或远端变更。`git fetch origin` 会访问网络，并更新本地远端跟踪引用与 `FETCH_HEAD`；执行前先确认 `origin` 指向 canonical repository：

```bash
git status --short --branch
git branch -vv
git fetch origin
git diff --stat
git diff
./scripts/git_summary.sh
./scripts/release_check.sh
```

`release_check.sh` 会强制列出所有未跟踪文件；显式 `--base` 必须是 `HEAD` 的严格祖先，不能用 `--base HEAD` 制造空差异。HEAD 尚未打 Tag、没有上游、使用 sparse-checkout/shallow clone、含未递归审计的 submodule gitlink 或远端证据不足时会返回非零退出码，这是预期的 fail-closed 行为，不得通过忽略退出码把它改成发布通过。自动化门禁必须拒绝任何非零退出并保存 warning 报告；`project.pbxproj`、依赖清单等正常发布变化产生的 warning 由独立 build/test required checks 闭环。只有零 warning 流水线才额外使用 `--strict`。

## 质量验证

```bash
find scripts shared/scripts tests -type f -name '*.sh' -exec sh -n {} +
find scripts shared/scripts tests -type f -name '*.sh' -exec bash -n {} +
shellcheck scripts/*.sh shared/scripts/*.sh tests/*.sh
./tests/integration.sh
```

还必须在 GitHub Actions 中确认 `Shell、Skill 与文档` 和 `macOS Shell 兼容性` 都成功。构建通过只证明静态门禁与仓库测试完成，不替代使用真实项目对 Skill 输出进行回归。

## 提交检查点

需要形成发布提交时，先完成工作区 Diff 分析并确认精确暂存范围。只暂存逐项审查过的路径；本 SOP 不提供可直接复制的全仓暂存命令。暂存完成后展示完整暂存差异：

```bash
git diff --cached --check
git diff --cached --stat
git diff --cached
./scripts/git_commit_check.sh
```

确认范围、风险和测试证据后，再单独确认是否执行中文 Conventional Commit。首次发布的建议提交信息为：

```text
feat: 发布 developer-agent-skills 0.1.0
```

## Tag 检查点

只有发布提交已经进入 `main`、CI 全部通过且本地 HEAD 与 `origin/main` 一致时，才进入 Tag 阶段。首次版本使用：

```bash
git tag -a v0.1.0 -m "release: v0.1.0"
git show --stat --decorate v0.1.0
./scripts/release_check.sh
```

创建 Tag 是独立写操作，执行前必须再次确认。`release_check.sh` 应识别唯一版本 `0.1.0`、HEAD Tag `v0.1.0`、已同步上游，并且没有阻断项或未知项；普通 warning 必须在 Release 审批中逐项关联到对应 required check。采用零 warning 政策时再追加 `--strict` 复检。

## Tag 与 Release 检查点

Tag 推送是独立远端操作。执行前再次展示目标、提交和 Tag，并获得确认：

```bash
git remote -v
git status --short --branch
git log -1 --oneline --decorate
git show --stat --decorate v0.1.0
git push origin v0.1.0
```

禁止 force push，禁止移动已经公开的版本 Tag。Tag 推送成功后：

1. 在仓库 **Settings → Releases** 中选择 **Enable release immutability**；该设置只保护启用后发布的 Release，操作依据见 [GitHub Immutable releases](https://docs.github.com/en/enterprise-cloud@latest/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes)；
2. 在 GitHub Releases 中选择现有 `v0.1.0` 并创建 Draft Release；
3. 使用 `CHANGELOG.md` 的对应内容生成 Release notes，核对安装命令、安全报告链接和源码归档；
4. 如需附加 ZIP 等资产，先记录 SHA-256，再放入 Draft；所有资产确认完成后才发布；
5. 发布后确认页面显示 Immutable，并核对 GitHub 生成的 release attestation；不可变发布生效后，不再替换 Tag 或资产。

## 发布后验证

- 从全新目录按 `docs/installation.md` 固定 Tag 的方式 clone；
- 检查六个 Skill 的 `SKILL.md`、`agents/openai.yaml` 和共享资源可读取；
- 运行 `./tests/integration.sh`；
- 确认 GitHub Release、CI Badge、License 和 Security advisory 入口可访问；
- 确认 Release 显示 Immutable，Tag 与资产不可修改，attestation 可核验；
- 记录未能自动验证的平台宿主行为，并在真实宿主中完成最小调用回归。

## 撤回与修复

发布前发现问题时停止 Tag 与 Release，不删除已有证据。已经公开的版本不得改写 Tag 或强制覆盖历史：

- 文档或脚本缺陷通过新的修复提交处理；
- 已发布版本存在高风险问题时，先在 `SECURITY.md` 约定的私密渠道评估影响；
- 发布新的补丁版本并在旧 Release 中标注受影响范围和升级建议；
- 需要撤下资产、删除 Tag 或改变仓库可见性时，先备份、列出影响并获得独立确认。

任何回滚都优先使用可审计的新提交，不使用 `git reset --hard`、force push 或递归强删。
