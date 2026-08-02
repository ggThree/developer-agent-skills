#!/bin/sh

set -u

script_path=$0
script_link_count=0
while [ -L "$script_path" ]; do
    script_link_count=$((script_link_count + 1))
    [ "$script_link_count" -le 32 ] || { printf '%s\n' '[错误] 脚本符号链接层级异常。' >&2; exit 127; }
    script_link_dir=$(CDPATH='' cd -P -- "$(dirname -- "$script_path")" && pwd) || exit 127
    script_link_target=$(readlink "$script_path") || { printf '%s\n' '[错误] 无法解析脚本符号链接。' >&2; exit 127; }
    case $script_link_target in
        /*) script_path=$script_link_target ;;
        *) script_path=$script_link_dir/$script_link_target ;;
    esac
done
SCRIPT_DIR=$(CDPATH='' cd -P -- "$(dirname -- "$script_path")" && pwd) || exit 127
LIB_PATH=$SCRIPT_DIR/../shared/scripts/lib.sh
[ -r "$LIB_PATH" ] || { printf '%s\n' '[错误] 无法读取可信 Shell 公共库。' >&2; exit 127; }
# shellcheck disable=SC1090
. "$LIB_PATH"

usage() {
    cat <<'USAGE'
用法：git_summary.sh

只读汇总当前 Git 仓库、分支、上游、工作区、暂存区和进行中的 Git 操作。
该脚本不会执行 fetch、add、commit、push、merge、rebase 或 reset。
USAGE
    das_print_exit_codes
}

case ${1:-} in
    -h|--help)
        usage
        exit 0
        ;;
    '') ;;
    *) das_usage_error "不支持的参数：$1" ;;
esac

das_require_git_repo
repo_root=$(das_repo_root)
cd "$repo_root" || das_die 3 "无法进入仓库根目录：$repo_root"

status_file=""
cleanup() {
    das_cleanup_files "$status_file"
}
on_signal() {
    signal_exit=$1
    trap - EXIT HUP INT TERM
    cleanup
    exit "$signal_exit"
}
status_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
trap cleanup EXIT
trap 'on_signal 129' HUP
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
das_git_status_file "$status_file" || das_die 4 "无法读取 Git 工作区状态。"

staged_count=$(awk '
    substr($0, 1, 2) != "??" && substr($0, 1, 1) != " " { count++ }
    END { print count + 0 }
' "$status_file")
unstaged_count=$(awk '
    substr($0, 1, 2) != "??" && substr($0, 2, 1) != " " { count++ }
    END { print count + 0 }
' "$status_file")
untracked_count=$(awk 'substr($0, 1, 2) == "??" { count++ } END { print count + 0 }' "$status_file")
conflict_count=$(awk '
    /^(DD|AU|UD|UA|DU|AA|UU)/ { count++ }
    END { print count + 0 }
' "$status_file")

branch=$(das_current_branch)
upstream=$(das_upstream 2>/dev/null) || upstream=""
stash_count=$(git stash list --format='%gd' 2>/dev/null | awk 'END { print NR + 0 }')

das_print_rule
printf 'Git 仓库摘要\n'
das_print_rule
das_print_key_value "仓库根目录" "$repo_root"
das_print_key_value "当前分支" "$branch"

if das_has_head; then
    head_summary=$(git log -1 --date=short --format='%h %ad %s')
    das_print_key_value "HEAD" "$head_summary"
else
    das_print_key_value "HEAD" "尚无提交"
fi

if [ -n "$upstream" ]; then
    das_print_key_value "上游分支" "$upstream"
    ahead_behind=$(das_ahead_behind HEAD "$upstream") || ahead_behind=""
    if [ -n "$ahead_behind" ]; then
        ahead=$(printf '%s\n' "$ahead_behind" | awk '{ print $1 + 0 }')
        behind=$(printf '%s\n' "$ahead_behind" | awk '{ print $2 + 0 }')
        das_print_key_value "同步状态" "领先 ${ahead}，落后 ${behind}（基于本地远端跟踪引用）"
    fi
else
    das_print_key_value "上游分支" "未配置"
fi

das_print_key_value "已暂存文件" "$staged_count"
das_print_key_value "未暂存文件" "$unstaged_count"
das_print_key_value "未跟踪文件" "$untracked_count"
das_print_key_value "冲突文件" "$conflict_count"
das_print_key_value "Stash 数量" "$stash_count"

git_dir=$(git rev-parse --git-dir)
operation="无"
if [ -f "$git_dir/MERGE_HEAD" ]; then
    operation="merge 进行中"
elif [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
    operation="rebase 进行中"
elif [ -f "$git_dir/CHERRY_PICK_HEAD" ]; then
    operation="cherry-pick 进行中"
elif [ -f "$git_dir/REVERT_HEAD" ]; then
    operation="revert 进行中"
fi
das_print_key_value "进行中的操作" "$operation"

das_print_rule
if [ "$conflict_count" -gt 0 ]; then
    das_warn "存在未解决冲突；请先处理冲突，再进行提交或分支操作。"
elif [ "$staged_count" -eq 0 ] && [ "$unstaged_count" -eq 0 ] && [ "$untracked_count" -eq 0 ]; then
    das_ok "工作区干净。"
else
    das_info "工作区存在变更；可继续使用 git_diff_summary.sh 和 git_changed_files.sh 查看细节。"
fi
