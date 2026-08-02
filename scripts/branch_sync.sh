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
用法：branch_sync.sh [--branch <本地分支>] [--remote <远端名>]

比较本地分支与其上游的领先、落后和分叉状态。默认检查当前分支与 origin。
脚本仅使用本地已有的远端跟踪引用，不执行 fetch、pull、push、merge 或 rebase。
USAGE
    das_print_exit_codes
}

branch_ref=""
remote_name="origin"
while [ "$#" -gt 0 ]; do
    case $1 in
        --branch)
            shift
            [ "$#" -gt 0 ] || das_usage_error "--branch 需要本地分支名。"
            branch_ref=$1
            ;;
        --remote)
            shift
            [ "$#" -gt 0 ] || das_usage_error "--remote 需要远端名。"
            remote_name=$1
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
das_has_head || das_die 4 "仓库尚无提交，无法检查分支同步。"

if ! git remote get-url "$remote_name" >/dev/null 2>&1; then
    das_die 5 "未找到远端：$remote_name"
fi

if [ -z "$branch_ref" ]; then
    branch_ref=$(das_current_branch)
    [ "$branch_ref" != "DETACHED" ] || das_die 5 "当前 HEAD detached；请使用 --branch 指定本地分支。"
fi
if ! git show-ref --verify --quiet "refs/heads/$branch_ref"; then
    das_die 5 "未找到本地分支：$branch_ref"
fi

upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "$branch_ref@{upstream}" 2>/dev/null) || upstream=""
status_file=""
# shellcheck disable=SC2329 # trap 按名称调用。
cleanup() {
    das_cleanup_files "$status_file"
}
# shellcheck disable=SC2329 # signal trap 按名称调用。
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

das_print_rule
printf '分支同步检查\n'
das_print_rule
das_print_key_value "本地分支" "$branch_ref"
das_print_key_value "指定远端" "$remote_name"

if [ -z "$upstream" ]; then
    das_print_key_value "上游分支" "未配置"
    printf '同步结论：无法判断\n'
    printf '已执行同步操作：否\n'
    das_error "请先人工核对目标远端分支；设置上游会影响后续 push/pull 行为，必须再次确认。"
    exit 1
fi
das_print_key_value "上游分支" "$upstream"

case $upstream in
    "$remote_name"/*) ;;
    *)
        printf '同步结论：无法判断\n'
        printf '已执行同步操作：否\n'
        das_error "上游不属于指定远端 ${remote_name}；拒绝用其他远端的状态代替本次检查。"
        exit 1
        ;;
esac

counts=$(das_ahead_behind "$branch_ref" "$upstream") ||
    das_die 5 "无法比较 ${branch_ref} 与 ${upstream}。"
ahead=$(printf '%s\n' "$counts" | awk '{ print $1 + 0 }')
behind=$(printf '%s\n' "$counts" | awk '{ print $2 + 0 }')
das_print_key_value "领先提交" "$ahead"
das_print_key_value "落后提交" "$behind"

upstream_time=$(git log -1 --format='%ad' --date=iso-strict "$upstream" 2>/dev/null) || upstream_time="未知"
das_print_key_value "上游引用提交时间" "$upstream_time"

das_git_status_file "$status_file" || das_die 4 "无法读取工作区状态。"
if [ -s "$status_file" ]; then
    das_warn "当前工作区存在未提交变更；进行任何同步操作前应先审查和妥善保存。"
fi

sync_ok=0
das_print_rule
if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
    printf '同步结论：基于本地引用已同步\n'
    sync_ok=1
elif [ "$ahead" -gt 0 ] && [ "$behind" -eq 0 ]; then
    printf '同步结论：本地领先，上游缺少本地提交\n'
    printf '建议：先审查 git log %s..%s，再决定是否 push。\n' "$upstream" "$branch_ref"
elif [ "$ahead" -eq 0 ] && [ "$behind" -gt 0 ]; then
    printf '同步结论：本地落后\n'
    printf '建议：先 fetch 并审查 git log %s..%s，再选择 merge 或 rebase。\n' "$branch_ref" "$upstream"
else
    printf '同步结论：本地与上游已分叉\n'
    printf '建议：检查 git log --left-right %s...%s，并根据分支共享情况选择 merge 或 rebase。\n' "$branch_ref" "$upstream"
    das_warn "分叉场景禁止未经确认直接 rebase 或强制推送。"
fi

default_ref=$(das_default_branch_ref "$remote_name" 2>/dev/null) || default_ref=""
if [ -n "$default_ref" ] && [ "$default_ref" != "$upstream" ]; then
    base_counts=$(das_ahead_behind "$branch_ref" "$default_ref") || base_counts=""
    if [ -n "$base_counts" ]; then
        base_ahead=$(printf '%s\n' "$base_counts" | awk '{ print $1 + 0 }')
        base_behind=$(printf '%s\n' "$base_counts" | awk '{ print $2 + 0 }')
        das_print_key_value "相对默认分支" "领先 ${base_ahead}，落后 ${base_behind}（${default_ref}）"
    fi
fi

das_print_rule
printf '已执行 fetch：否\n'
printf '已执行同步操作：否\n'
das_info "结果可能因远端跟踪引用过期而失真；先明确执行 git fetch ${remote_name}，再重新检查。"

if [ "$sync_ok" -eq 1 ]; then
    exit 0
fi
exit 1
