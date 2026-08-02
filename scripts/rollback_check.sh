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
用法：
  rollback_check.sh restore [--staged] <路径>...
  rollback_check.sh revert <提交>
  rollback_check.sh reset [--soft|--mixed] <目标引用>

只分析 restore、revert、reset --soft 和 reset --mixed 的影响，不执行回滚。
明确拒绝 --hard。任何实际回滚都必须备份、复核影响并再次确认。
USAGE
    das_print_exit_codes
}

[ "$#" -gt 0 ] || das_usage_error "缺少回滚模式。"
case $1 in
    -h|--help)
        usage
        exit 0
        ;;
esac

das_require_git_repo
repo_root=$(das_repo_root)
cd "$repo_root" || das_die 3 "无法进入仓库根目录：$repo_root"
das_has_head || das_die 4 "仓库尚无提交，无法执行回滚分析。"

mode=$1
shift
case $mode in
    restore)
        restore_staged=0
        if [ "${1:-}" = "--staged" ]; then
            restore_staged=1
            shift
        fi
        [ "$#" -gt 0 ] || das_usage_error "restore 必须显式指定至少一个路径。"
        case " $* " in
            *" --hard "*) das_die 6 "安全策略拒绝 --hard。" ;;
        esac

        diff_file=""
        cleanup() {
            das_cleanup_files "$diff_file"
        }
        on_signal() {
            signal_exit=$1
            trap - EXIT HUP INT TERM
            cleanup
            exit "$signal_exit"
        }
        diff_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
        trap cleanup EXIT
        trap 'on_signal 129' HUP
        trap 'on_signal 130' INT
        trap 'on_signal 143' TERM
        if [ "$restore_staged" -eq 1 ]; then
            git -c core.quotePath=false diff --cached --stat -- "$@" >"$diff_file" ||
                das_die 4 "无法分析指定路径的暂存差异。"
        else
            git -c core.quotePath=false diff --stat -- "$@" >"$diff_file" ||
                das_die 4 "无法分析指定路径的工作区差异。"
        fi

        das_print_rule
        printf 'restore 回滚分析\n'
        das_print_key_value "仓库" "$repo_root"
        das_print_key_value "路径数量" "$#"
        das_print_key_value "仅撤出暂存" "$restore_staged"
        das_print_rule
        if [ -s "$diff_file" ]; then
            cat "$diff_file"
        else
            das_warn "指定路径在所选范围内没有可见差异；请确认路径和当前状态。"
        fi
        if [ "$restore_staged" -eq 1 ]; then
            printf '影响：从暂存区撤出所选变更，工作区内容保留。\n'
            printf '建议：先保存 git diff --cached，再人工确认 git restore --staged -- <路径>。\n'
        else
            printf '影响：覆盖所选路径的未暂存内容；未提交修改可能无法恢复。\n'
            printf '建议：先生成补丁或复制到仓库外的备份位置，再人工确认 git restore -- <路径>。\n'
            printf '说明：git stash 也是独立写操作，如需使用必须另行分析并确认。\n'
        fi
        printf '已执行回滚：否\n'
        ;;
    revert)
        [ "$#" -eq 1 ] || das_usage_error "revert 需要且只接受一个提交引用。"
        revert_ref=$1
        das_validate_ref "$revert_ref" || das_die 5 "无法解析提交：$revert_ref"
        parent_line=$(git rev-list --parents -n 1 "$revert_ref")
        parent_count=$(printf '%s\n' "$parent_line" | awk '{ print NF - 1 }')

        das_print_rule
        printf 'revert 回滚分析\n'
        das_print_key_value "提交" "$(git rev-parse --short "$revert_ref")"
        das_print_key_value "父提交数量" "$parent_count"
        git -c core.quotePath=false show --stat --summary --format='%h %ad %an%n%s' --date=short "$revert_ref"
        das_print_rule
        if [ "$parent_count" -gt 1 ]; then
            das_warn "目标是合并提交；revert 需要选择 mainline 父提交，不能自动给出安全命令。"
        else
            printf '影响：创建一个反向提交，保留公开历史，通常适合已推送提交。\n'
            printf '建议：先检查依赖提交，再人工确认 git revert <提交>。\n'
        fi
        if [ -n "$(git status --porcelain)" ]; then
            das_warn "当前工作区不干净，执行 revert 前必须先妥善保存或提交现有变更。"
        fi
        printf '已执行回滚：否\n'
        ;;
    reset)
        reset_mode="--mixed"
        case ${1:-} in
            --hard) das_die 6 "安全策略禁止 reset --hard；请使用 restore、revert、--soft 或 --mixed。" ;;
            --soft|--mixed)
                reset_mode=$1
                shift
                ;;
            --*) das_usage_error "reset 不支持该模式：$1" ;;
        esac
        [ "$#" -eq 1 ] || das_usage_error "reset 需要一个目标引用。"
        reset_ref=$1
        das_validate_ref "$reset_ref" || das_die 5 "无法解析 reset 目标：$reset_ref"

        commit_file=""
        changed_file=""
        status_file=""
        staged_file=""
        worktree_file=""
        cleanup() {
            das_cleanup_files "$commit_file" "$changed_file" "$status_file" \
                "$staged_file" "$worktree_file"
        }
        on_signal() {
            signal_exit=$1
            trap - EXIT HUP INT TERM
            cleanup
            exit "$signal_exit"
        }
        commit_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
        trap cleanup EXIT
        trap 'on_signal 129' HUP
        trap 'on_signal 130' INT
        trap 'on_signal 143' TERM
        changed_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
        status_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
        staged_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
        worktree_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
        git log --oneline --decorate "$reset_ref..HEAD" >"$commit_file" ||
            das_die 4 "无法读取 reset 将移出的提交。"
        git -c core.quotePath=false diff --stat "$reset_ref..HEAD" >"$changed_file" ||
            das_die 4 "无法读取 reset 的提交差异。"
        das_git_status_file "$status_file" || das_die 4 "无法读取工作区状态。"
        git -c core.quotePath=false diff --cached --stat >"$staged_file" ||
            das_die 4 "无法读取当前暂存差异。"
        git -c core.quotePath=false diff --stat >"$worktree_file" ||
            das_die 4 "无法读取当前未暂存差异。"
        commit_count=$(das_count_lines "$commit_file")
        reset_safe=1

        das_print_rule
        printf 'reset 回滚分析\n'
        das_print_key_value "模式" "$reset_mode"
        das_print_key_value "目标" "$reset_ref ($(git rev-parse --short "$reset_ref"))"
        das_print_key_value "移出分支提交" "$commit_count"
        if [ -s "$status_file" ]; then
            reset_safe=0
            das_error "当前工作区不干净；reset 候选被阻断，必须先独立备份并处理现有变更。"
            das_print_rule
            printf '当前工作区状态：\n'
            das_print_excerpt "$status_file" 30
            printf '当前暂存差异统计：\n'
            if [ -s "$staged_file" ]; then cat "$staged_file"; else printf '%s\n' '（无）'; fi
            printf '当前未暂存差异统计：\n'
            if [ -s "$worktree_file" ]; then cat "$worktree_file"; else printf '%s\n' '（无）'; fi
        fi
        if ! git merge-base --is-ancestor "$reset_ref" HEAD; then
            reset_safe=0
            das_error "目标不是 HEAD 的祖先；拒绝把跨历史 reset 作为可执行候选。"
        fi
        if [ "$commit_count" -gt 0 ]; then
            das_print_rule
            printf '将移出当前分支可达范围的提交：\n'
            das_print_excerpt "$commit_file" 30
            printf '文件统计：\n'
            cat "$changed_file"
        fi
        if [ "$reset_mode" = "--soft" ]; then
            printf '影响：移动分支指针，差异保留在暂存区。\n'
        else
            printf '影响：移动分支指针并重置暂存区，差异保留在工作区。\n'
        fi
        printf '备份建议：先创建明确命名的备份分支，并记录当前 HEAD：%s\n' "$(git rev-parse HEAD)"
        printf '恢复建议：误操作后优先通过 git reflog 找回原 HEAD。\n'
        printf '已执行回滚：否\n'
        das_warn "reset 会改写分支指针；即使使用 --soft 或 --mixed，也必须再次确认。"
        if [ "$reset_safe" -eq 0 ]; then
            printf '是否可进入 reset 执行确认：否\n'
            exit 1
        fi
        printf '是否可进入 reset 执行确认：是（仍需针对精确命令再次确认）\n'
        ;;
    *)
        das_usage_error "未知回滚模式：$mode"
        ;;
esac
