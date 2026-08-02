# Shell 公共能力

`shared/scripts/lib.sh` 为仓库根目录 `scripts/` 下的检查脚本提供一致的输出、Git 环境检查、引用解析、临时文件和统计能力。公共库只定义函数，被加载时不会读取或修改 Git 仓库。

## 兼容范围

- macOS 自带 Bash 3.2 与 `/bin/sh`
- Linux 常见的 Bash、Dash
- Git 2.x
- 不依赖 GNU 专属的 `sed`、`grep`、`stat` 参数

## 使用方式

```sh
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/../shared/scripts/lib.sh"

das_require_git_repo
das_info "开始非侵入式检查"
```

调用方应先执行 `das_require_git_repo`，再调用仓库相关函数。临时文件由 `das_make_temp_file` 创建，脚本应使用 `trap` 配合 `das_cleanup_files` 清理。

## 退出码约定

| 退出码 | 含义 |
| --- | --- |
| `0` | 检查完成且没有阻断项 |
| `1` | 检查完成，但发现阻断项或不建议继续 |
| `2` | 参数或用法错误 |
| `3` | 当前目录不是 Git 工作树 |
| `4` | 缺少执行检查所需的对象或变更 |
| `5` | 引用、分支或比较基线无效 |
| `6` | 安全策略明确拒绝的操作 |
| `127` | 缺少必需命令或无法加载可信公共库 |
| `129` | 收到 HUP 并安全中止 |
| `130` | 收到 INT 并安全中止 |
| `143` | 收到 TERM 并安全中止 |

## 安全边界

公共库不封装 `push`、`merge`、`rebase`、`reset` 等写操作。上层脚本即使展示建议命令，也必须明确说明尚未执行，并要求操作者再次确认。

`das_cleanup_files` 只删除由调用方显式传入的普通临时文件。`das_cleanup_tree` 只接受 `das_make_temp_dir` 命名空间中的精确临时目录，并用逐项清理代替递归强删。

检查脚本不改变工作区内容、refs 或暂存内容；Git 的 `status`、`diff` 等命令可能刷新 index 的 stat 元数据，因此这里的“非侵入式”不是字节级只读承诺。
