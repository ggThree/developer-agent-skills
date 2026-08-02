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
用法：git_diff_summary.sh [选项]

  --all             分别汇总已暂存、未暂存和未跟踪文件（默认）
  --staged          仅汇总暂存区与 HEAD 的差异
  --worktree        仅汇总工作区与暂存区的差异
  --head            汇总工作区与 HEAD 的全部已跟踪差异
  --base <ref>      汇总 <ref>...HEAD 的提交差异
  -h, --help        显示帮助

该脚本只输出统计，不执行任何写操作。
USAGE
    das_print_exit_codes
}

mode="all"
base_ref=""
while [ "$#" -gt 0 ]; do
    case $1 in
        --all) mode="all" ;;
        --staged) mode="staged" ;;
        --worktree) mode="worktree" ;;
        --head) mode="head" ;;
        --base)
            shift
            [ "$#" -gt 0 ] || das_usage_error "--base 需要一个 Git 引用。"
            mode="base"
            base_ref=$1
            ;;
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

if [ "$mode" = "base" ] && ! das_validate_ref "$base_ref"; then
    das_die 5 "无法解析比较基线：$base_ref"
fi
if { [ "$mode" = "head" ] || [ "$mode" = "base" ]; } && ! das_has_head; then
    das_die 4 "仓库尚无 HEAD，无法进行所选比较。"
fi

numstat_file=""
cleanup() {
    das_cleanup_files "$numstat_file"
}
on_signal() {
    signal_exit=$1
    trap - EXIT HUP INT TERM
    cleanup
    exit "$signal_exit"
}
numstat_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
trap cleanup EXIT
trap 'on_signal 129' HUP
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

print_diff_section() {
    diff_title=$1
    shift
    das_print_rule
    printf '%s\n' "$diff_title"

    if git diff --quiet "$@"; then
        das_ok "没有差异。"
        return 0
    fi

    if ! git diff --numstat "$@" >"$numstat_file"; then
        das_error "无法生成差异统计：$diff_title"
        return 1
    fi

    git -c core.quotePath=false diff --stat --compact-summary "$@"
    awk '
        BEGIN { files = 0; added = 0; deleted = 0; binary = 0 }
        {
            files++
            if ($1 == "-" || $2 == "-") {
                binary++
            } else {
                added += $1
                deleted += $2
            }
        }
        END {
            printf "文件：%d，新增：%d，删除：%d，二进制：%d\n", files, added, deleted, binary
        }
    ' "$numstat_file"
}

das_print_rule
printf 'Git 差异摘要\n'
das_print_key_value "仓库" "$repo_root"

case $mode in
    all)
        if das_has_head; then
            print_diff_section "已暂存：HEAD → 暂存区" --cached || exit 1
        else
            print_diff_section "已暂存：空树 → 暂存区" --cached || exit 1
        fi
        print_diff_section "未暂存：暂存区 → 工作区" || exit 1
        untracked_count=$(git ls-files --others --exclude-standard | awk 'END { print NR + 0 }')
        das_print_rule
        das_print_key_value "未跟踪文件" "$untracked_count"
        ;;
    staged)
        print_diff_section "已暂存差异" --cached || exit 1
        ;;
    worktree)
        print_diff_section "未暂存差异" || exit 1
        ;;
    head)
        print_diff_section "HEAD → 当前工作区" HEAD || exit 1
        ;;
    base)
        print_diff_section "$base_ref...HEAD 的提交差异" "$base_ref...HEAD" || exit 1
        ;;
esac

das_print_rule
das_info "摘要不包含未跟踪文件内容；需要文件清单时请运行 git_changed_files.sh。"
