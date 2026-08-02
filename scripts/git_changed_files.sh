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
用法：git_changed_files.sh [--all|--staged|--worktree|--untracked] [--name-only]

  --all         显示全部工作区状态（默认）
  --staged      仅显示已暂存文件
  --worktree    显示未暂存及未跟踪文件
  --untracked   仅显示未跟踪文件
  --name-only   只输出去重后的路径，不输出状态码

状态码采用 Git 的 XY 格式；脚本不会修改文件或暂存区。
USAGE
    das_print_exit_codes
}

mode="all"
name_only=0
while [ "$#" -gt 0 ]; do
    case $1 in
        --all) mode="all" ;;
        --staged) mode="staged" ;;
        --worktree) mode="worktree" ;;
        --untracked) mode="untracked" ;;
        --name-only) name_only=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) das_usage_error "不支持的参数：$1" ;;
    esac
    shift
done

das_require_git_repo
repo_root=$(das_repo_root)
cd "$repo_root" || das_die 3 "无法进入仓库根目录：$repo_root"

output_file=""
work_file=""
staged_file=""
unstaged_file=""
untracked_file=""
cleanup() {
    das_cleanup_files "$output_file" "$work_file" "$staged_file" \
        "$unstaged_file" "$untracked_file"
}
on_signal() {
    signal_exit=$1
    trap - EXIT HUP INT TERM
    cleanup
    exit "$signal_exit"
}
output_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
trap cleanup EXIT
trap 'on_signal 129' HUP
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
work_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
staged_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
unstaged_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
untracked_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"

case $mode in
    all)
        if [ "$name_only" -eq 1 ]; then
            git -c core.quotePath=false diff --cached --name-only >"$staged_file" ||
                das_die 4 "无法读取已暂存文件清单。"
            git -c core.quotePath=false diff --name-only >"$unstaged_file" ||
                das_die 4 "无法读取未暂存文件清单。"
            git -c core.quotePath=false ls-files --others --exclude-standard >"$untracked_file" ||
                das_die 4 "无法读取未跟踪文件清单。"
            cat "$staged_file" "$unstaged_file" "$untracked_file" >"$work_file" ||
                das_die 4 "无法合并变更文件清单。"
            LC_ALL=C sort -u "$work_file" >"$output_file" ||
                das_die 4 "无法整理变更文件清单。"
        else
            das_git_status_file "$output_file" || das_die 4 "无法读取工作区状态。"
        fi
        ;;
    staged)
        if [ "$name_only" -eq 1 ]; then
            git -c core.quotePath=false diff --cached --name-only >"$output_file" ||
                das_die 4 "无法读取已暂存文件清单。"
        else
            git -c core.quotePath=false diff --cached --name-status >"$output_file" ||
                das_die 4 "无法读取已暂存文件状态。"
        fi
        ;;
    worktree)
        if [ "$name_only" -eq 1 ]; then
            git -c core.quotePath=false diff --name-only >"$unstaged_file" ||
                das_die 4 "无法读取未暂存文件清单。"
            git -c core.quotePath=false ls-files --others --exclude-standard >"$untracked_file" ||
                das_die 4 "无法读取未跟踪文件清单。"
            cat "$unstaged_file" "$untracked_file" >"$work_file" ||
                das_die 4 "无法合并工作区文件清单。"
            LC_ALL=C sort -u "$work_file" >"$output_file" ||
                das_die 4 "无法整理工作区文件清单。"
        else
            git -c core.quotePath=false diff --name-status >"$output_file" ||
                das_die 4 "无法读取未暂存文件状态。"
            git -c core.quotePath=false ls-files --others --exclude-standard >"$untracked_file" ||
                das_die 4 "无法读取未跟踪文件清单。"
            sed 's/^/??\t/' "$untracked_file" >>"$output_file" ||
                das_die 4 "无法格式化未跟踪文件状态。"
        fi
        ;;
    untracked)
        if [ "$name_only" -eq 1 ]; then
            git -c core.quotePath=false ls-files --others --exclude-standard >"$output_file" ||
                das_die 4 "无法读取未跟踪文件清单。"
        else
            git -c core.quotePath=false ls-files --others --exclude-standard >"$untracked_file" ||
                das_die 4 "无法读取未跟踪文件清单。"
            sed 's/^/??\t/' "$untracked_file" >"$output_file" ||
                das_die 4 "无法格式化未跟踪文件状态。"
        fi
        ;;
esac

count=$(das_count_lines "$output_file")
das_print_rule
printf 'Git 变更文件清单\n'
das_print_key_value "范围" "$mode"
das_print_key_value "文件数" "$count"
das_print_rule

if [ "$count" -eq 0 ]; then
    das_ok "所选范围内没有变更文件。"
else
    if [ "$name_only" -eq 0 ] && [ "$mode" = "all" ]; then
        printf '状态码说明：左列为暂存区，右列为工作区，?? 为未跟踪。\n'
    fi
    cat "$output_file"
fi
