# Merge 分析报告模板

本模板用于在执行 `merge`、`rebase` 或 `squash` 前给出基于分支事实的建议。分析不等于授权；任何实际合并、变基和推送都必须再次确认。

## 输入证据

至少采集：

```sh
git status --short --branch
git branch -vv
git log --graph --oneline --decorate --all -n 40
git merge-base <source> <target>
git diff --stat <target>...<source>
git diff --name-status <target>...<source>
```

远端状态应在核对 remote 后通过本轮 `git fetch origin` 刷新；执行前说明网络和引用更新副作用，用户明确禁止网络访问时标为未验证。不得把旧的本地 tracking 信息当成实时远端事实。

## 输出结构

### 分支关系

说明 source、target、共同祖先、ahead/behind、是否存在未提交改动，以及比较数据的采集时间。

### 策略建议

在下列策略中选择并解释：

- `merge`：保留完整分支历史，适合已共享分支或合并节点具有审计价值的场景。
- `rebase`：形成线性历史，仅适合尚未共享或已确认可重写的提交。
- `squash`：把实现过程压成单一意图，适合碎片提交较多且不需要逐提交保留的功能分支。
- `暂不合并`：基线过期、验证失败、风险未决或证据不足。

### 冲突预测

列出双方共同修改的文件、生成文件、依赖锁文件、工程配置、迁移脚本与高耦合模块。预测必须标记为推断；只有实际试合并才能确认冲突。

### 风险与验证

说明策略对 Commit SHA、CI、代码审查、二分定位、发布和回滚的影响，并给出合并前后最小验证。

### 建议命令

只展示与结论一致的非破坏性命令序列。执行前写明检查点；不得自动附带 `push`，不得建议 `git push --force`。

## 完整示例

```text
结论：建议 merge，暂不 rebase。

分支关系：feature/login 比 main 领先 4 个提交、落后 2 个提交；该分支已由两名开发者共享。
依据：重写历史会改变已共享 Commit SHA；保留合并节点有利于审计本次登录改造。
冲突预测：双方均修改 package-lock.json 与 src/api/auth.ts，需人工核对依赖解析和接口字段。
合并前验证：工作区干净；feature/login 的 CI 通过；先在临时分支演练并审查合并 Diff。
合并后验证：运行登录模块测试，核对成功、超时、权限失效三条路径。
```

更完整的策略边界见 [`../references/branching.md`](../references/branching.md) 和 [`../rules/git.md`](../rules/git.md)。
