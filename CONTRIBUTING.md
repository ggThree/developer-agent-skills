# 贡献指南

感谢你帮助改进 `developer-agent-skills`。项目优先接受可复现、最小侵入、可在真实仓库中安全运行的改进。

## 开始之前

1. 阅读根目录的 [AGENTS.md](AGENTS.md) 与 [架构说明](docs/architecture.md)。
2. 搜索现有 Issue，确认问题尚未被处理。
3. 对新增 Skill、公共接口或行为不兼容变更，先提交设计 Issue，说明场景、风险与验收标准。
4. 安全漏洞不要公开提交 Issue，按 [SECURITY.md](SECURITY.md) 私下报告。

## 本地开发

```bash
git clone https://github.com/ggThree/developer-agent-skills.git
cd developer-agent-skills
find scripts shared/scripts tests -type f -name '*.sh' -exec sh -n {} +
find scripts shared/scripts tests -type f -name '*.sh' -exec bash -n {} +
shellcheck scripts/*.sh shared/scripts/*.sh tests/*.sh
./tests/integration.sh
```

若系统尚未安装 `shellcheck`，macOS 可使用 Homebrew，Debian/Ubuntu 可使用系统包管理器安装。项目脚本本身不依赖 Homebrew。

## 分支与提交

- 从最新默认分支创建短生命周期分支，如 `feat/add-gitlab-adapter` 或 `fix/release-tag-check`。
- 一次提交只处理一个逻辑目标。
- 默认使用中文 Conventional Commit，例如 `fix(release-check): 修正无 Tag 仓库的判断`。
- 不提交生成日志、编辑器配置、真实凭据和与改动无关的格式化结果。

## Pull Request 要求

PR 描述需包含：

- 问题与用户场景；
- 方案与未采用方案；
- 影响目录和兼容性；
- 风险等级与回滚方式；
- 实际执行的验证命令及结果；
- 新增或改变行为对应的示例。

维护者会重点检查危险命令防护、macOS/Linux 兼容性、Skill 触发描述、共享规则复用和文档一致性。

版本发布由维护者按 [Release SOP](docs/releasing.md) 执行。提交 PR 不代表授权创建 Tag、推送或发布 GitHub Release。

## 新增 Skill 的最低标准

- 包含有效 `SKILL.md` 和 `agents/openai.yaml`；
- 包含至少一个完整的真实场景示例；
- 复用 `shared/` 中的模板、规则和风险模型；
- 把确定性检查放入可测试脚本，危险操作保持人工确认；
- 更新 README、架构、使用文档、更新日志和相关验证。

提交贡献即表示你同意按本仓库 [MIT License](LICENSE) 授权该贡献。
