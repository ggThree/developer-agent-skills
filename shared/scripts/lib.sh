#!/bin/sh

# developer-agent-skills 的 shell 公共库。
# 仅定义函数；被 source 时不会读取或修改仓库状态。

DAS_LIB_VERSION="0.1.0"

das_lib_version() {
    printf '%s\n' "$DAS_LIB_VERSION"
}

das_info() {
    printf '[信息] %s\n' "$*"
}

das_ok() {
    printf '[通过] %s\n' "$*"
}

das_warn() {
    printf '[警告] %s\n' "$*" >&2
}

das_error() {
    printf '[错误] %s\n' "$*" >&2
}

das_die() {
    das_exit_code=$1
    shift
    das_error "$*"
    exit "$das_exit_code"
}

das_usage_error() {
    das_error "$*"
    printf '请使用 --help 查看用法。\n' >&2
    exit 2
}

das_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

das_require_git() {
    if ! das_command_exists git; then
        das_die 127 "未找到 git，请先安装 Git 并确认其位于 PATH 中。"
    fi
}

das_require_git_repo() {
    das_require_git
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        das_die 3 "当前目录不在 Git 工作树中。"
    fi
}

das_repo_root() {
    git rev-parse --show-toplevel
}

das_current_branch() {
    das_branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || das_branch=""
    if [ -n "$das_branch" ]; then
        printf '%s\n' "$das_branch"
    else
        printf '%s\n' "DETACHED"
    fi
}

das_has_head() {
    git rev-parse --verify HEAD >/dev/null 2>&1
}

das_validate_ref() {
    git rev-parse --verify "$1^{commit}" >/dev/null 2>&1
}

das_upstream() {
    git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null
}

das_ahead_behind() {
    das_left_ref=$1
    das_right_ref=$2
    git rev-list --left-right --count "$das_left_ref...$das_right_ref" 2>/dev/null
}

das_default_branch_ref() {
    das_remote=${1:-origin}
    das_symbolic=$(git symbolic-ref --quiet --short "refs/remotes/$das_remote/HEAD" 2>/dev/null) || das_symbolic=""
    if [ -n "$das_symbolic" ] && das_validate_ref "$das_symbolic"; then
        printf '%s\n' "$das_symbolic"
        return 0
    fi

    for das_candidate in "$das_remote/main" "$das_remote/master" main master; do
        if das_validate_ref "$das_candidate"; then
            printf '%s\n' "$das_candidate"
            return 0
        fi
    done
    return 1
}

das_make_temp_file() {
    das_tmp_root=${TMPDIR:-/tmp}
    umask 077
    mktemp "$das_tmp_root/developer-agent-skills.XXXXXX"
}

das_make_temp_dir() {
    das_tmp_root=${TMPDIR:-/tmp}
    umask 077
    mktemp -d "$das_tmp_root/developer-agent-skills.XXXXXX"
}

das_count_lines() {
    if [ ! -s "$1" ]; then
        printf '0\n'
        return 0
    fi
    awk 'END { print NR + 0 }' "$1"
}

das_print_excerpt() {
    das_excerpt_file=$1
    das_excerpt_limit=${2:-20}
    if [ -s "$das_excerpt_file" ]; then
        sed -n "1,${das_excerpt_limit}p" "$das_excerpt_file"
    fi
}

das_is_integer() {
    case $1 in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

das_semver_compare() {
    [ "$#" -eq 2 ] || return 2
    LC_ALL=C awk -v left="$1" -v right="$2" '
        function parse(value, core_parts, pre_parts, build_parts,
            clean, plus_position, build_value, build_count,
            dash_position, core_value, pre_value, core_count,
            pre_count, part_index) {
            clean = value
            plus_position = index(clean, "+")
            if (plus_position > 0) {
                build_value = substr(clean, plus_position + 1)
                clean = substr(clean, 1, plus_position - 1)
                if (build_value == "") return 0
                build_count = split(build_value, build_parts, ".")
                for (part_index = 1; part_index <= build_count; part_index++) {
                    if (build_parts[part_index] !~ /^[0-9A-Za-z-]+$/) return 0
                }
            }

            dash_position = index(clean, "-")
            if (dash_position > 0) {
                pre_value = substr(clean, dash_position + 1)
                core_value = substr(clean, 1, dash_position - 1)
                if (pre_value == "") return 0
            } else {
                pre_value = ""
                core_value = clean
            }

            core_count = split(core_value, core_parts, ".")
            if (core_count != 3) return 0
            for (part_index = 1; part_index <= core_count; part_index++) {
                if (core_parts[part_index] !~ /^(0|[1-9][0-9]*)$/) return 0
            }

            pre_parts[0] = 0
            if (pre_value != "") {
                pre_count = split(pre_value, pre_parts, ".")
                pre_parts[0] = pre_count
                for (part_index = 1; part_index <= pre_count; part_index++) {
                    if (pre_parts[part_index] !~ /^[0-9A-Za-z-]+$/) return 0
                    if (pre_parts[part_index] ~ /^[0-9]+$/ &&
                        length(pre_parts[part_index]) > 1 &&
                        substr(pre_parts[part_index], 1, 1) == "0") return 0
                }
            }
            return 1
        }

        function compare_numeric(left_value, right_value) {
            if (length(left_value) < length(right_value)) return -1
            if (length(left_value) > length(right_value)) return 1
            if (("x" left_value) < ("x" right_value)) return -1
            if (("x" left_value) > ("x" right_value)) return 1
            return 0
        }

        BEGIN {
            if (!parse(left, left_core, left_pre, left_build) ||
                !parse(right, right_core, right_pre, right_build)) exit 2

            for (component = 1; component <= 3; component++) {
                result = compare_numeric(left_core[component], right_core[component])
                if (result != 0) {
                    print result
                    exit 0
                }
            }

            left_pre_count = left_pre[0]
            right_pre_count = right_pre[0]
            if (left_pre_count == 0 && right_pre_count == 0) {
                print 0
                exit 0
            }
            if (left_pre_count == 0) {
                print 1
                exit 0
            }
            if (right_pre_count == 0) {
                print -1
                exit 0
            }

            max_pre_count = left_pre_count
            if (right_pre_count > max_pre_count) max_pre_count = right_pre_count
            for (component = 1; component <= max_pre_count; component++) {
                if (component > left_pre_count) {
                    print -1
                    exit 0
                }
                if (component > right_pre_count) {
                    print 1
                    exit 0
                }
                left_numeric = left_pre[component] ~ /^[0-9]+$/
                right_numeric = right_pre[component] ~ /^[0-9]+$/
                if (left_numeric && right_numeric) {
                    result = compare_numeric(left_pre[component], right_pre[component])
                } else if (left_numeric) {
                    result = -1
                } else if (right_numeric) {
                    result = 1
                } else if (("x" left_pre[component]) < ("x" right_pre[component])) {
                    result = -1
                } else if (("x" left_pre[component]) > ("x" right_pre[component])) {
                    result = 1
                } else {
                    result = 0
                }
                if (result != 0) {
                    print result
                    exit 0
                }
            }
            print 0
        }
    ' </dev/null
}

das_print_rule() {
    printf '%s\n' '------------------------------------------------------------'
}

das_print_key_value() {
    printf '%-18s %s\n' "$1：" "$2"
}

das_print_exit_codes() {
    cat <<'EXIT_CODES'

退出码：
  0    检查完成，未发现阻断项
  1    检查完成，但存在阻断项或结论无法安全确认
  2    参数或用法错误
  3    当前目录不是可用的 Git 工作树
  4    缺少检查所需状态，或本地检查执行失败
  5    Git 引用、远端或比较关系无效
  6    请求了安全策略明确禁止的操作
  127  缺少必要命令或无法加载可信公共库
  129  收到 HUP 并安全中止
  130  收到 INT 并安全中止
  143  收到 TERM 并安全中止
EXIT_CODES
}

das_git_status_file() {
    das_status_output=$1
    git -c core.quotePath=false status --porcelain=v1 --untracked-files=all \
        >"$das_status_output"
}

das_cleanup_files() {
    for das_cleanup_path in "$@"; do
        if [ -n "$das_cleanup_path" ] && [ -f "$das_cleanup_path" ]; then
            rm -f -- "$das_cleanup_path"
        fi
    done
}

das_cleanup_tree() {
    das_cleanup_root=$1
    das_expected_tmp=${TMPDIR:-/tmp}
    case $das_cleanup_root in
        "$das_expected_tmp"/developer-agent-skills.*) ;;
        *)
            das_error "拒绝清理不可信临时目录：$das_cleanup_root"
            return 1
            ;;
    esac
    if [ -d "$das_cleanup_root" ] && [ ! -L "$das_cleanup_root" ]; then
        find "$das_cleanup_root" -depth -type f -exec rm -f -- {} \;
        find "$das_cleanup_root" -depth -type l -exec rm -f -- {} \;
        find "$das_cleanup_root" -depth -type d -exec rmdir {} \;
    fi
}
