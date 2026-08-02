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
用法：git_branch.sh [--all]

  --all    同时显示本地分支和远端跟踪分支

只读检查分支、上游和领先/落后关系。结果基于本地已有的远端跟踪引用；
脚本不会自动执行 git fetch。
USAGE
    das_print_exit_codes
}

show_all=0
case ${1:-} in
    -h|--help)
        usage
        exit 0
        ;;
    --all) show_all=1 ;;
    '') ;;
    *) das_usage_error "不支持的参数：$1" ;;
esac
if [ "$#" -gt 1 ]; then
    das_usage_error "参数过多。"
fi

das_require_git_repo
repo_root=$(das_repo_root)
cd "$repo_root" || das_die 3 "无法进入仓库根目录：$repo_root"

current=$(das_current_branch)
upstream=$(das_upstream 2>/dev/null) || upstream=""
default_ref=$(das_default_branch_ref origin 2>/dev/null) || default_ref="未识别"

das_print_rule
printf 'Git 分支检查\n'
das_print_rule
das_print_key_value "当前分支" "$current"
das_print_key_value "默认分支参考" "$default_ref"

if [ -n "$upstream" ]; then
    das_print_key_value "上游分支" "$upstream"
    counts=$(das_ahead_behind HEAD "$upstream") || counts=""
    if [ -n "$counts" ]; then
        ahead=$(printf '%s\n' "$counts" | awk '{ print $1 + 0 }')
        behind=$(printf '%s\n' "$counts" | awk '{ print $2 + 0 }')
        das_print_key_value "领先提交" "$ahead"
        das_print_key_value "落后提交" "$behind"
        if [ "$behind" -gt 0 ]; then
            das_warn "当前分支落后上游。请先执行 git fetch，复核差异后再决定 merge 或 rebase。"
        fi
    fi
else
    das_print_key_value "上游分支" "未配置"
    das_warn "当前分支没有上游；如需发布，请人工确认远端与目标分支。"
fi

das_print_rule
if [ "$show_all" -eq 1 ]; then
    printf '本地与远端跟踪分支：\n'
    git -c color.branch=false branch -a -vv
else
    printf '本地分支：\n'
    git -c color.branch=false branch -vv
fi

gone_branches=$(git -c color.branch=false branch -vv | awk '/\[[^]]*: gone\]/{ count++ } END { print count + 0 }')
das_print_rule
das_print_key_value "上游已消失分支" "$gone_branches"
if [ "$gone_branches" -gt 0 ]; then
    das_warn "发现上游已消失的本地分支；删除前应确认分支内容已合并或已备份。"
fi
das_info "以上远端状态可能过期；本脚本未执行 fetch。"
