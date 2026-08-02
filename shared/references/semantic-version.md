# Semantic Versioning 参考

Semantic Versioning（SemVer）用 `MAJOR.MINOR.PATCH` 表达公开契约的兼容程度。采用 SemVer 的前提是团队先定义“公开 API”：它可能包括代码 API、HTTP Schema、CLI、配置、数据格式、插件协议和用户可依赖的行为。

## 1. 版本结构

```text
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

例如：

```text
2.4.1
3.0.0-beta.2
1.8.0-rc.1+build.20260802
```

核心版本号均为非负整数，不能使用前导零。

## 2. 递增规则

| 变化 | 递增 | 示例 |
| --- | --- | --- |
| 不兼容的公开 API 变化 | MAJOR | `2.7.3` → `3.0.0` |
| 向后兼容的新能力 | MINOR | `2.7.3` → `2.8.0` |
| 向后兼容的问题修复 | PATCH | `2.7.3` → `2.7.4` |

递增 MAJOR 时 MINOR、PATCH 归零；递增 MINOR 时 PATCH 归零。

版本选择由相对当前发布版本的最高影响决定。一次发布包含多个修复和一个向后兼容功能，应增加 MINOR；包含任一破坏性变化，应增加 MAJOR。

## 3. 破坏性变化判断

常见 MAJOR 信号：

- 删除、重命名或收紧公开 API；
- 改变字段类型、单位、时区、枚举语义或错误码；
- 提高最低运行时、系统或数据库版本，使在用环境无法升级；
- 修改数据格式，使旧数据或旧客户端不能读取；
- 改变默认认证、权限或配置行为，导致现有部署失败。

增加可选字段、增加向后兼容 endpoint、内部重构通常不是 MAJOR。但旧调用方能否继续正确运行必须通过契约和兼容测试证明。

## 4. Pre-release

Pre-release 使用连字符追加点分标识符：

```text
2.5.0-alpha.1
2.5.0-beta.3
2.5.0-rc.1
```

Pre-release 优先级低于对应正式版本。标识符从左到右比较：纯数字按数值比较，非数字按 ASCII 词法比较；字段更多的一方在共同字段相同后优先级更高。

Pre-release 表示稳定性和兼容承诺尚未达到正式版本，不应作为跳过测试或发布记录的理由。

## 5. Build Metadata

Build metadata 使用 `+` 追加：

```text
2.5.0+sha.1a2b3c4
2.5.0-rc.1+ci.842
```

Build metadata 不参与版本优先级比较。需要区分制品时，可额外记录完整 Commit SHA、CI run 与构建环境；不能依赖 metadata 决定升级顺序。

## 6. 0.y.z 阶段

`0.y.z` 表示公开 API 仍可能快速变化。团队仍应记录兼容影响：

- `0.MINOR.0` 可用于明显不兼容变化；
- `0.y.PATCH` 用于向后兼容修复；
- 使用者不能仅凭 `0` 推断每次升级都安全或都不安全。

一旦公开契约稳定且已有真实使用者，应发布 `1.0.0` 并明确兼容承诺。

## 7. 版本不可变性

版本一经发布，其内容不得修改。发现问题应发布新版本，不能让相同版本号指向不同代码或制品。Tag、制品摘要、依赖清单与发布说明应共同建立可追溯性。

## 8. 多平台版本源

| 平台 | 常见公开版本 | 构建标识 | 检查重点 |
| --- | --- | --- | --- |
| npm | `package.json` version | registry 制品完整性 | workspace 包之间约束与 lockfile |
| iOS | `CFBundleShortVersionString` | `CFBundleVersion` | App/Extension 一致性、渠道规则 |
| Spring/Java | Maven/Gradle artifact version | CI build/镜像 digest | BOM、容器与部署清单一致性 |
| Git | annotated Tag | Commit SHA | Tag 指向准确发布 Commit且不可移动 |

仓库若有单一版本源，应由脚本派生其他位置；若必须多处维护，发布检查要验证一致性。

## 9. 与 Commit 的关系

Conventional Commit 可以辅助自动判断：

- `fix` 倾向 PATCH；
- `feat` 倾向 MINOR；
- `!` 或 `BREAKING CHANGE:` 倾向 MAJOR。

这只是自动化输入，不取代公开 API 审查。分类方法见 [`conventional-commit.md`](conventional-commit.md)。

## 10. 发布决策清单

1. 定义本仓库公开契约。
2. 比较上一个发布 Tag 到候选 Commit 的完整 Diff。
3. 识别破坏性变化、功能和修复。
4. 选择最高影响对应版本并核对所有版本文件。
5. 运行兼容、升级和回滚验证。
6. 生成 [`../templates/release_note.md`](../templates/release_note.md)。
7. 按 [`../rules/release-rule.md`](../rules/release-rule.md) 完成门禁后创建 Tag。
