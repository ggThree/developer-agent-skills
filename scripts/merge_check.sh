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
用法：merge_check.sh [目标引用] [源引用] [--strategy merge|rebase|squash]

默认源引用为 HEAD；未指定目标引用时，尝试识别 origin 的默认分支。
脚本分析祖先关系、提交数量、重叠文件和可预测冲突，并给出 merge、rebase、
squash 建议。它不会执行 fetch、merge、rebase、squash、commit 或 push。
USAGE
    das_print_exit_codes
}

target_ref=""
source_ref="HEAD"
strategy="auto"
positional_count=0
while [ "$#" -gt 0 ]; do
    case $1 in
        --strategy)
            shift
            [ "$#" -gt 0 ] || das_usage_error "--strategy 需要 merge、rebase 或 squash。"
            case $1 in
                merge|rebase|squash) strategy=$1 ;;
                *) das_usage_error "未知策略：$1" ;;
            esac
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*) das_usage_error "不支持的参数：$1" ;;
        *)
            positional_count=$((positional_count + 1))
            case $positional_count in
                1) target_ref=$1 ;;
                2) source_ref=$1 ;;
                *) das_usage_error "位置参数过多。" ;;
            esac
            ;;
    esac
    shift
done

das_require_git_repo
repo_root=$(das_repo_root)
cd "$repo_root" || das_die 3 "无法进入仓库根目录：$repo_root"
das_has_head || das_die 4 "仓库尚无提交，无法分析合并。"

git_dir=$(git rev-parse --git-dir) || das_die 4 "无法定位 Git 目录。"
ongoing_operations=""
append_operation() {
    if [ -n "$ongoing_operations" ]; then
        ongoing_operations="${ongoing_operations}、$1"
    else
        ongoing_operations=$1
    fi
}
[ -f "$git_dir/MERGE_HEAD" ] && append_operation "merge"
if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
    append_operation "rebase"
fi
[ -f "$git_dir/CHERRY_PICK_HEAD" ] && append_operation "cherry-pick"
[ -f "$git_dir/REVERT_HEAD" ] && append_operation "revert"
if [ -n "$ongoing_operations" ]; then
    das_print_rule
    printf '合并分析\n'
    das_error "仓库存在未完成的 Git 操作：${ongoing_operations}。先完成或安全中止当前操作，再重新分析。"
    printf '是否建议现在合并：否\n'
    exit 1
fi

if [ -z "$target_ref" ]; then
    target_ref=$(das_default_branch_ref origin 2>/dev/null) ||
        das_die 5 "无法识别默认目标分支；请显式传入目标引用。"
fi
das_validate_ref "$target_ref" || das_die 5 "无法解析目标引用：$target_ref"
das_validate_ref "$source_ref" || das_die 5 "无法解析源引用：$source_ref"

target_commit=$(git rev-parse "$target_ref^{commit}")
source_commit=$(git rev-parse "$source_ref^{commit}")
if [ "$target_commit" = "$source_commit" ]; then
    das_print_rule
    printf '合并分析\n'
    das_print_key_value "目标" "$target_ref"
    das_print_key_value "源" "$source_ref"
    das_ok "目标与源指向同一提交，无需合并。"
    exit 0
fi

merge_base=$(git merge-base "$target_ref" "$source_ref") ||
    das_die 5 "目标与源没有共同祖先，不能进行常规合并分析。"

target_paths=""
source_paths=""
overlap_paths=""
merge_tree_file=""
status_file=""
merge_object_dir=""
cleanup() {
    das_cleanup_files "$target_paths" "$source_paths" "$overlap_paths" \
        "$merge_tree_file" "$status_file"
    if [ -n "$merge_object_dir" ]; then
        das_cleanup_tree "$merge_object_dir"
    fi
}
on_signal() {
    signal_exit=$1
    trap - EXIT HUP INT TERM
    cleanup
    exit "$signal_exit"
}
target_paths=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
trap cleanup EXIT
trap 'on_signal 129' HUP
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
source_paths=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
overlap_paths=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
merge_tree_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
status_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"

if ! git -c core.quotePath=false diff --name-only "$merge_base..$target_ref" >"$status_file"; then
    das_die 4 "无法读取目标侧变更路径。"
fi
LC_ALL=C sort -u "$status_file" >"$target_paths" || das_die 4 "无法整理目标侧变更路径。"
if ! git -c core.quotePath=false diff --name-only "$merge_base..$source_ref" >"$status_file"; then
    das_die 4 "无法读取源侧变更路径。"
fi
LC_ALL=C sort -u "$status_file" >"$source_paths" || das_die 4 "无法整理源侧变更路径。"
LC_ALL=C comm -12 "$target_paths" "$source_paths" >"$overlap_paths" ||
    das_die 4 "无法计算两侧重叠路径。"

target_commits=$(git rev-list --count "$merge_base..$target_ref")
source_commits=$(git rev-list --count "$merge_base..$source_ref")
overlap_count=$(das_count_lines "$overlap_paths")
blockers=0
warnings=0

das_print_rule
printf '合并分析\n'
das_print_rule
das_print_key_value "目标引用" "$target_ref"
das_print_key_value "源引用" "$source_ref"
das_print_key_value "共同祖先" "$(git rev-parse --short "$merge_base")"
das_print_key_value "目标侧提交" "$target_commits"
das_print_key_value "源侧提交" "$source_commits"
das_print_key_value "重叠文件" "$overlap_count"
das_print_key_value "指定策略" "$strategy"

das_git_status_file "$status_file" || das_die 4 "无法读取工作区状态。"
if [ -s "$status_file" ]; then
    blockers=$((blockers + 1))
    das_error "当前工作区不干净，不应直接开始 merge 或 rebase。"
    das_print_excerpt "$status_file" 20
else
    das_ok "当前工作区干净。"
fi

relationship="双方已分叉"
if git merge-base --is-ancestor "$target_ref" "$source_ref"; then
    relationship="目标是源的祖先，可 fast-forward"
elif git merge-base --is-ancestor "$source_ref" "$target_ref"; then
    relationship="源已包含在目标中，无需合并"
fi
das_print_key_value "祖先关系" "$relationship"

if [ "$overlap_count" -gt 0 ]; then
    warnings=$((warnings + 1))
    das_warn "两侧修改了相同路径，需重点审查："
    das_print_excerpt "$overlap_paths" 30
else
    das_ok "两侧没有重叠修改路径。"
fi

merge_tree_help_status=0
git merge-tree -h >"$status_file" 2>&1 || merge_tree_help_status=$?
: "$merge_tree_help_status"
merge_write_support=0
grep -- '--write-tree' "$status_file" >/dev/null 2>&1 || merge_write_support=$?
if [ "$merge_write_support" -eq 0 ]; then
    merge_object_dir=$(das_make_temp_dir) || das_die 4 "无法创建隔离的 merge-tree 对象目录。"
    git_common_dir=$(git rev-parse --git-common-dir) || das_die 4 "无法定位 Git 公共目录。"
    case $git_common_dir in
        /*) ;;
        *) git_common_dir=$repo_root/$git_common_dir ;;
    esac
    git_objects_dir=$git_common_dir/objects
    [ -d "$git_objects_dir" ] || das_die 4 "无法定位现有 Git 对象目录。"

    merge_tree_status=0
    merge_tree_conflict=0
    line_feed='
'
    tab_character=$(printf '\t')
    carriage_return=$(printf '\r')
    alternate_ready=1
    case $git_objects_dir in
        *"$line_feed"*|*"$tab_character"*|*"$carriage_return"*) alternate_ready=0 ;;
    esac
    if [ "$alternate_ready" -eq 1 ]; then
        escaped_objects_dir=$(printf '%s' "$git_objects_dir" |
            sed 's/\\/\\\\/g; s/"/\\"/g') || das_die 4 "无法编码 Git 对象目录。"
        alternate_objects_value=\"$escaped_objects_dir\"
        GIT_OBJECT_DIRECTORY=$merge_object_dir \
        GIT_ALTERNATE_OBJECT_DIRECTORIES=$alternate_objects_value \
            git merge-tree --write-tree --messages "$target_ref" "$source_ref" \
            >"$merge_tree_file" 2>&1 || merge_tree_status=$?
    else
        merge_tree_status=2
        printf '%s\n' 'Git 对象目录包含不支持的控制字符。' >"$merge_tree_file"
    fi
    case $merge_tree_status in
        0)
            das_ok "现代 merge-tree 在隔离对象目录中完成预演，未预测到冲突。"
            ;;
        1)
            blockers=$((blockers + 1))
            merge_error_status=0
            grep -E '(^|[[:space:]])(fatal:|error:)|not something we can merge|unknown revision' \
                "$merge_tree_file" >/dev/null 2>&1 || merge_error_status=$?
            if [ "$merge_error_status" -eq 0 ]; then
                das_error "现代 merge-tree 返回执行错误，无法可靠判断冲突；按 fail-closed 处理。"
            elif [ "$merge_error_status" -eq 1 ]; then
                merge_tree_conflict=1
                das_error "现代 merge-tree 预测到冲突："
                das_print_excerpt "$merge_tree_file" 30
            else
                das_error "无法分类 merge-tree 结果；按 fail-closed 处理。"
            fi
            ;;
        *)
            blockers=$((blockers + 1))
            das_error "现代 merge-tree 预演执行失败，无法可靠判断冲突；按 fail-closed 处理。"
            ;;
    esac
elif [ "$merge_write_support" -eq 1 ]; then
    blockers=$((blockers + 1))
    das_error "当前 Git 不支持可靠的 merge-tree --write-tree；旧三参数模式不会用于安全结论。"
else
    blockers=$((blockers + 1))
    das_error "无法判断当前 Git 是否支持现代 merge-tree；按 fail-closed 处理。"
fi

if [ -s "$merge_tree_file" ] && [ "${merge_tree_conflict:-0}" -eq 1 ]; then
    conflict_scan_status=0
    grep -E 'CONFLICT|changed in both|Auto-merging' "$merge_tree_file" >"$status_file" || conflict_scan_status=$?
    if [ "$conflict_scan_status" -eq 0 ]; then
        :
    elif [ "$conflict_scan_status" -eq 1 ]; then
        das_warn "merge-tree 返回冲突状态，但未生成可分类的消息；仍保持阻断。"
    else
        blockers=$((blockers + 1))
        das_error "无法解析 merge-tree 冲突消息；保持 fail-closed。"
    fi
fi

das_print_rule
printf '策略建议\n'
if git merge-base --is-ancestor "$source_ref" "$target_ref"; then
    printf '%s\n' '- 无需 merge、rebase 或 squash；源提交已在目标历史中。'
elif git merge-base --is-ancestor "$target_ref" "$source_ref"; then
    printf '%s\n' '- 优先评估 fast-forward merge，可保持线性历史且不重写源提交。'
elif [ "$source_commits" -eq 1 ]; then
    printf '%s\n' '- 源侧只有 1 个提交，优先 merge；squash 不会进一步压缩历史。'
else
    printf '%s\n' '- 分支已分叉：共享分支优先 merge；仅在源分支私有且未被他人基于其开发时考虑 rebase。'
    printf '%s\n' '- 若源提交包含大量修正型历史且项目要求单提交，可在审查后选择 squash。'
fi

case $strategy in
    rebase)
        warnings=$((warnings + 1))
        das_warn "rebase 会重写源分支提交 ID；必须确认分支私有，并在执行前再次确认。"
        ;;
    squash)
        warnings=$((warnings + 1))
        das_warn "squash 会丢失目标分支中的逐提交语义；请先确认审计和回滚需求。"
        ;;
    merge|auto) ;;
esac

das_print_rule
das_print_key_value "阻断项" "$blockers"
das_print_key_value "警告项" "$warnings"
printf '已执行合并操作：否\n'
if [ "$blockers" -gt 0 ]; then
    printf '是否建议现在合并：否\n'
    exit 1
fi
printf '是否建议现在合并：可进入人工确认\n'
das_info "远端引用可能过期；执行任何 merge、rebase 或 push 前必须 fetch、复核并再次确认。"
