# 安装

## 前置条件

- macOS 或 Linux；
- Git 2.38 或更高版本；2.30 至 2.37 可运行基础检查，但 `merge_check.sh` 会因缺少可靠的 `merge-tree --write-tree` 能力而 fail-closed；
- Bash 3.2 或更高版本；
- Python 3.8 或更高版本，用于结构化解析 XML 与 binary plist；
- 目标宿主已支持基于 `SKILL.md` 的 Agent Skills。

`shellcheck` 仅用于开发和 CI 校验，运行 Skills 时不是必需依赖。
当目标仓库的候选 `HEAD` 包含 `package.json` 时，`release_check.sh` 使用目标项目的 `node` 解析顶层版本、依赖字段与 `workspaces`；若当前环境没有 `node`，脚本会按未知证据返回非零退出码，不会用正则猜测 JSON 结构。
当候选提交包含 plist 时，`release_check.sh` 使用 Python 3 标准库 `plistlib` 结构化解析 XML 与 binary plist；解析器缺失、结构损坏或根类型异常时按未知证据返回非零，不用文本正则冒充 plist 校验。

## 获取当前发布候选

```bash
git clone --depth 1 https://github.com/ggThree/developer-agent-skills.git
cd developer-agent-skills
git rev-parse HEAD
```

当前仓库尚未发布稳定 Tag。上面的浅克隆会固定在克隆当时的 Commit，不会自行更新；请保存 `git rev-parse HEAD` 的输出，并在升级前审查新旧 Commit 差异。不要只下载单个 `SKILL.md`。各 Skill 会按需使用根级 `scripts/` 与 `shared/`，保留完整仓库可以确保规则、模板和脚本版本一致。正式团队采用前，应等待经过验证的 GitHub Release，或由团队明确批准并固定一个 Commit。

参与贡献或验证开发中变更时，使用独立目录跟踪默认分支：

```bash
git clone https://github.com/ggThree/developer-agent-skills.git developer-agent-skills-main
cd developer-agent-skills-main
```

## Codex

Codex 官方文档说明，仓库级和用户级 Skills 从 `.agents/skills` 发现。建议使用符号链接保留完整仓库拓扑。

用户级安装一个 Skill：

```bash
mkdir -p "${HOME}/.agents/skills"
ln -s "$(pwd)/skills/Git/safe-git-workflow" "${HOME}/.agents/skills/safe-git-workflow"
```

项目级安装：

```bash
mkdir -p /path/to/project/.agents/skills
ln -s "$(pwd)/skills/Git/review-diff" /path/to/project/.agents/skills/review-diff
```

该命令创建的是指向本机 clone 的绝对符号链接，仅用于本机项目级发现，不得直接提交到团队仓库。团队共享应把完整 `developer-agent-skills` 固定到已审查的 Commit/Tag 后放入受控 vendor 或 submodule 目录，再创建仓库内可移植的相对链接；同时确保链接后的物理 Skill 路径仍能访问根级 `scripts/` 与 `shared/`。

在 Codex CLI 或 IDE 扩展中可使用 `$safe-git-workflow`，或先运行 `/skills` 检查发现结果。Codex 通常能检测 Skill 变化；未显示时重启当前宿主。参考：[OpenAI Build skills](https://developers.openai.com/codex/skills)。

## ChatGPT

ChatGPT 桌面端支持 standalone skills，并通过 Skills 界面展示和管理。打开桌面端侧边栏的 Skills，按当前界面引导添加本仓库中的具体 Skill 目录。显式使用时输入 `@` 选择 Skill。

ChatGPT 的分发与导入界面可能随产品版本变化，因此本项目不提供未经官方保证的本地配置路径。以 [OpenAI Build skills](https://developers.openai.com/codex/skills) 的当前说明和客户端界面为准。

## Claude Code

Claude Code 的用户级目录是 `~/.claude/skills`，项目级目录是 `.claude/skills`。

```bash
mkdir -p "${HOME}/.claude/skills"
ln -s "$(pwd)/skills/Git/release-check" "${HOME}/.claude/skills/release-check"
```

可通过 `/release-check` 显式调用，也可以让 Claude 根据 description 自动选择。若在会话启动后首次创建顶级 skills 目录，重启 Claude Code 以确保目录监控生效。参考：[Claude Code Skills](https://code.claude.com/docs/en/skills)。

## Cursor

Cursor 支持 `SKILL.md` Agent Skills。优先使用开放的 `.agents/skills` 路径，以便与 Codex 共用项目配置；也可使用 Cursor 专用的 `.cursor/skills`。

```bash
mkdir -p /path/to/project/.agents/skills
ln -s "$(pwd)/skills/Git/commit-message" /path/to/project/.agents/skills/commit-message
```

在 Agent 输入框使用斜杠菜单显式调用。若 Skill 未出现，先检查 Cursor 版本、目录名、frontmatter 和 Settings 中的 Skills 可见性，再参考 [Cursor Agent Skills](https://cursor.com/docs/skills)。

## 安装全部 Skills

以下命令只创建不存在的链接；遇到同名目标会失败并保留原文件，便于人工处理冲突。

```bash
mkdir -p "${HOME}/.agents/skills"
for skill_dir in "$(pwd)"/skills/Git/*; do
  [ -d "${skill_dir}" ] || continue
  skill_name=$(basename "${skill_dir}")
  ln -s "${skill_dir}" "${HOME}/.agents/skills/${skill_name}"
done
```

为 Claude Code 安装时，把目标目录改为 `${HOME}/.claude/skills`。

## 切换至已发布稳定版

仅当 GitHub Releases 已存在对应版本时，才按稳定版处理。稳定版升级必须显式选择已经审查的 Tag，不自动解析或切换到所谓“最新版本”。首个 `v0.1.0` 发布后可执行：

```bash
git status --short --branch
git fetch --tags --prune
git tag --list 'v*' --sort=-v:refname
git show --stat v0.1.0
git switch --detach v0.1.0
```

命令执行前必须先在 GitHub Release 页面确认 `v0.1.0` 已真实发布。后续版本发布后，先阅读对应 Release 与 `CHANGELOG.md`，再显式切换到该真实 Tag 并重新运行验证。若本地有修改，先创建独立分支保存和审查，不要覆盖。

## 更新开发版

仅在专门跟踪 `main` 的开发目录中执行：

```bash
git status --short --branch
git pull --ff-only
```

若本地有修改，不要直接覆盖。先创建分支并审查差异，或重新 clone 到新目录后切换符号链接。任何版本更新后都应运行：

```bash
find scripts shared/scripts -type f -name '*.sh' -exec bash -n {} +
shellcheck scripts/*.sh shared/scripts/*.sh
```

## 卸载

只删除你亲自创建、且确认仍为符号链接的目标。例如：

```bash
ls -l "${HOME}/.agents/skills/review-diff"
unlink "${HOME}/.agents/skills/review-diff"
```

`unlink` 不会删除本仓库中的真实 Skill。不要对 Skills 根目录执行递归删除。
