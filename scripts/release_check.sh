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
用法：release_check.sh [--base <ref>] [--strict]

  --base <ref>   指定 HEAD 的严格祖先作为比较基线；默认使用上一个可达 Tag
  --strict       将警告和未知项全部升级为发布阻断项
  -h, --help     显示帮助

检查范围：工作区与冲突、分支同步、未完成标记、调试输出、iOS/Node/
Spring 工程与依赖文件、版本号、Tag 和发布差异。脚本不执行构建、fetch、
tag、push、merge、rebase 或 reset，也不修改工作区内容、refs 或暂存内容。
Git 自身可能刷新 index 的 stat 元数据。稀疏工作树只能得到未知结论；解析
package.json 与 package.json.workspaces 的顶层字段需要 node。
USAGE
    das_print_exit_codes
}

strict=0
base_ref=""
while [ "$#" -gt 0 ]; do
    case $1 in
        --base)
            shift
            [ "$#" -gt 0 ] || das_usage_error "--base 需要一个 Git 引用。"
            base_ref=$1
            ;;
        --strict) strict=1 ;;
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
das_has_head || das_die 4 "仓库尚无提交，不能执行发布检查。"

status_file=""
changed_file=""
deleted_file=""
tracked_file=""
gitlink_file=""
index_flags_file=""
hidden_index_file=""
scan_raw_file=""
pending_file=""
diagnostic_file=""
diagnostic_flag_file=""
diagnostic_plist_paths_file=""
diagnostic_plist_blob_file=""
diagnostic_plist_unknown_file=""
conflict_file=""
tree_entry_file=""
version_source_file=""
version_blob_file=""
baseline_blob_file=""
version_file=""
version_value_file=""
unresolved_version_file=""
version_reference_file=""
build_source_file=""
build_file=""
build_value_file=""
unresolved_build_file=""
build_reference_file=""
tag_file=""
misc_file=""
node_owner_raw_file=""
node_owner_file=""
plist_python=""
cleanup() {
    das_cleanup_files "$status_file" "$changed_file" "$deleted_file" "$tracked_file" \
        "$gitlink_file" "$index_flags_file" "$hidden_index_file" "$scan_raw_file" "$pending_file" \
        "$diagnostic_file" "$diagnostic_flag_file" "$diagnostic_plist_paths_file" \
        "$diagnostic_plist_blob_file" "$diagnostic_plist_unknown_file" \
        "$conflict_file" "$tree_entry_file" \
        "$version_source_file" \
        "$version_blob_file" "$baseline_blob_file" "$version_file" "$version_value_file" \
        "$unresolved_version_file" "$version_reference_file" "$build_source_file" "$build_file" \
        "$build_value_file" \
        "$unresolved_build_file" "$build_reference_file" "$tag_file" "$misc_file" \
        "$node_owner_raw_file" "$node_owner_file"
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
changed_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
deleted_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
tracked_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
gitlink_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
index_flags_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
hidden_index_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
scan_raw_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
pending_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
diagnostic_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
diagnostic_flag_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
diagnostic_plist_paths_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
diagnostic_plist_blob_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
diagnostic_plist_unknown_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
conflict_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
tree_entry_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
version_source_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
version_blob_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
baseline_blob_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
version_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
version_value_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
unresolved_version_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
version_reference_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
build_source_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
build_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
build_value_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
unresolved_build_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
build_reference_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
tag_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
misc_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
node_owner_raw_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
node_owner_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
plist_python=$(command -v python3 2>/dev/null) || plist_python=""

blockers=0
warnings=0
unknowns=0

add_blocker() {
    blockers=$((blockers + 1))
    das_error "$*"
}

add_warning() {
    warnings=$((warnings + 1))
    das_warn "$*"
}

add_unknown() {
    unknowns=$((unknowns + 1))
    das_warn "[未知] $*"
}

redact_scan_locations() {
    redact_input=$1
    redact_output=$2
    redact_label=$3
    awk -v label="$redact_label" '
        match($0, /:[0-9]+:/) {
            print substr($0, 1, RSTART + RLENGTH - 1) " [" label "内容已脱敏]"
            next
        }
        match($0, /:\[plist\]:/) {
            print substr($0, 1, RSTART + RLENGTH - 1) " [" label "内容已脱敏]"
            next
        }
        { print "[位置无法解析]: [" label "内容已脱敏]" }
    ' "$redact_input" >"$redact_output"
}

plist_query() {
    plist_query_path=$1
    plist_query_mode=$2
    plist_query_key=${3:-}
    [ -n "$plist_python" ] || return 127
    "$plist_python" -c '
import plistlib
import re
import sys

path, mode, requested_key = sys.argv[1:4]
try:
    with open(path, "rb") as handle:
        payload = plistlib.load(handle)
except Exception:
    raise SystemExit(2)

def enabled(value):
    if value is True:
        return True
    if isinstance(value, str):
        return value.strip().lower() in {"true", "yes", "on", "1"}
    if isinstance(value, int) and not isinstance(value, bool):
        return value == 1
    return False

def is_debug_key(value):
    if not isinstance(value, str):
        return False
    lowered = value.lower()
    if lowered == "debug" or re.search(r"(^|[_\-.])[d]ebug($|[_\-.])", lowered):
        return True
    return bool(re.search(r"Debug$|^debug[A-Z]", value))

def contains_enabled_debug(value):
    if isinstance(value, dict):
        for key, nested in value.items():
            if is_debug_key(key) and enabled(nested):
                return True
            if contains_enabled_debug(nested):
                return True
    elif isinstance(value, list):
        return any(contains_enabled_debug(item) for item in value)
    return False

if mode == "debug":
    raise SystemExit(0 if contains_enabled_debug(payload) else 1)
if not isinstance(payload, dict):
    raise SystemExit(4)
if mode == "has-version":
    keys = {"CFBundleShortVersionString", "CFBundleVersion"}
    raise SystemExit(0 if keys.intersection(payload) else 1)
if mode == "field":
    if requested_key not in payload:
        raise SystemExit(1)
    value = payload[requested_key]
    if not isinstance(value, str):
        raise SystemExit(3)
    sys.stdout.write(value + "\n")
    raise SystemExit(0)
raise SystemExit(5)
    ' "$plist_query_path" "$plist_query_mode" "$plist_query_key"
}

scan_repository_pattern() {
    scan_pattern=$1
    scan_label=$2
    scan_output=$3
    scan_ignore_case=$4
    : >"$scan_raw_file"
    : >"$scan_output"
    scan_status=0
    if [ "$scan_ignore_case" -eq 1 ]; then
        git grep -n -I -i -E "$scan_pattern" HEAD -- \
            '*.h' '*.m' '*.mm' '*.swift' '*.c' '*.cc' '*.cpp' '*.cxx' \
            '*.html' '*.htm' '*.vue' '*.svelte' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' \
            '*.java' '*.kt' '*.kts' '*.py' '*.go' '*.rs' '*.rb' '*.php' '*.sh' \
            '*.xml' '*.yml' '*.yaml' '*.properties' '*.xcconfig' '*.plist' \
            '*.pbxproj' '*.gradle' '*.gradle.kts' '*.json' 'Podfile' 'Package.swift' \
            >"$scan_raw_file" 2>/dev/null || scan_status=$?
    else
        git grep -n -I -E "$scan_pattern" HEAD -- \
            '*.h' '*.m' '*.mm' '*.swift' '*.c' '*.cc' '*.cpp' '*.cxx' \
            '*.html' '*.htm' '*.vue' '*.svelte' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' \
            '*.java' '*.kt' '*.kts' '*.py' '*.go' '*.rs' '*.rb' '*.php' '*.sh' \
            '*.xml' '*.yml' '*.yaml' '*.properties' '*.xcconfig' '*.plist' \
            '*.pbxproj' '*.gradle' '*.gradle.kts' '*.json' 'Podfile' 'Package.swift' \
            >"$scan_raw_file" 2>/dev/null || scan_status=$?
    fi
    case $scan_status in
        0)
            if ! redact_scan_locations "$scan_raw_file" "$scan_output" "$scan_label"; then
                return 2
            fi
            return 0
            ;;
        1) return 1 ;;
        *) return 2 ;;
    esac
}

scan_repository_diagnostics() {
    diagnostic_output=$1
    : >"$scan_raw_file"
    : >"$diagnostic_flag_file"
    : >"$diagnostic_plist_paths_file"
    : >"$diagnostic_plist_blob_file"
    : >"$diagnostic_plist_unknown_file"
    : >"$diagnostic_output"

    diagnostic_call_pattern='(^|[^[:alnum:]_])((print|nslog|debugprint)[[:space:]]*\(|console\.(log|debug)[[:space:]]*\(|([[:alnum:]_]+[.])?debug[[:space:]]*\(|debugger[[:space:]]*;)'
    diagnostic_call_status=0
    git grep -n -I -i -E "$diagnostic_call_pattern" HEAD -- \
        '*.h' '*.m' '*.mm' '*.swift' '*.c' '*.cc' '*.cpp' '*.cxx' \
        '*.html' '*.htm' '*.vue' '*.svelte' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' \
        '*.java' '*.kt' '*.kts' '*.py' '*.go' '*.rs' '*.rb' '*.php' '*.sh' \
        >"$scan_raw_file" 2>/dev/null || diagnostic_call_status=$?
    case $diagnostic_call_status in
        0|1) ;;
        *) return 2 ;;
    esac

    diagnostic_flag_pattern="(^|[,{])[[:space:]]*(export[[:space:]]+)?[\"']?([[:alnum:]_]+_)?debug[\"']?[[:space:]]*[:=][[:space:]]*[\"']?(true|yes|on|1)[\"']?([[:space:],;}]|\$)"
    diagnostic_flag_status=0
    git grep -n -I -i -E "$diagnostic_flag_pattern" HEAD -- \
        '*.json' '*.yml' '*.yaml' '*.properties' '*.xcconfig' \
        '.env' '.env.*' '*.env' '*.env.*' \
        >"$diagnostic_flag_file" 2>/dev/null || diagnostic_flag_status=$?
    case $diagnostic_flag_status in
        0)
            if ! awk '
                !/(^|[\/:])(package-lock\.json|npm-shrinkwrap\.json):[0-9]+:/ { print }
            ' "$diagnostic_flag_file" >>"$scan_raw_file"; then
                return 2
            fi
            ;;
        1) ;;
        *) return 2 ;;
    esac

    awk '/\.plist$/ { print }' "$tracked_file" >"$diagnostic_plist_paths_file" || return 2
    while IFS= read -r diagnostic_plist_path; do
        [ -n "$diagnostic_plist_path" ] || continue
        diagnostic_plist_blob_status=0
        head_blob_to_file "$diagnostic_plist_path" "$diagnostic_plist_blob_file" ||
            diagnostic_plist_blob_status=$?
        case $diagnostic_plist_blob_status in
            0) ;;
            3)
                printf '%s\n' "${diagnostic_plist_path}（不是普通文件）" \
                    >>"$diagnostic_plist_unknown_file"
                continue
                ;;
            *) return 2 ;;
        esac

        diagnostic_plist_query_status=0
        plist_query "$diagnostic_plist_blob_file" debug "" >/dev/null 2>&1 ||
            diagnostic_plist_query_status=$?
        case $diagnostic_plist_query_status in
            0)
                printf 'HEAD:%s:[plist]:[plist debug enabled]\n' \
                    "$diagnostic_plist_path" >>"$scan_raw_file"
                ;;
            1) ;;
            2|3|4|127)
                printf '%s\n' "${diagnostic_plist_path}（解析器不可用或 plist 结构无效）" \
                    >>"$diagnostic_plist_unknown_file"
                ;;
            *) return 2 ;;
        esac
    done <"$diagnostic_plist_paths_file"

    if [ ! -s "$scan_raw_file" ]; then
        return 1
    fi
    redact_scan_locations "$scan_raw_file" "$diagnostic_output" "调试代码" || return 2
    return 0
}

count_paths() {
    path_pattern=$1
    awk -v pattern="$path_pattern" '$0 ~ pattern { count++ } END { print count + 0 }' "$tracked_file"
}

changed_has() {
    path_pattern=$1
    awk -v pattern="$path_pattern" '
        $0 ~ pattern { found = 1 }
        END { if (found) exit 0; exit 1 }
    ' "$changed_file"
}

path_file_contains() {
    path_list_file=$1
    path_list_value=$2
    path_list_status=0
    LC_ALL=C grep -F -x -e "$path_list_value" "$path_list_file" >/dev/null 2>&1 ||
        path_list_status=$?
    case $path_list_status in
        0) return 0 ;;
        1) return 1 ;;
        *) return 2 ;;
    esac
}

path_dirname() {
    case $1 in
        */*) printf '%s\n' "${1%/*}" ;;
        *) printf '%s\n' '.' ;;
    esac
}

path_join() {
    path_join_dir=$1
    path_join_name=$2
    case $path_join_dir in
        .) printf '%s\n' "$path_join_name" ;;
        *) printf '%s/%s\n' "$path_join_dir" "$path_join_name" ;;
    esac
}

head_blob_to_file() {
    head_blob_path=$1
    head_blob_output=$2
    : >"$tree_entry_file"
    : >"$head_blob_output"

    git ls-tree HEAD -- ":(literal)$head_blob_path" >"$tree_entry_file" || return 2
    [ "$(das_count_lines "$tree_entry_file")" -eq 1 ] || return 2

    head_blob_mode=$(awk 'NR == 1 { print $1 }' "$tree_entry_file") || return 2
    head_blob_type=$(awk 'NR == 1 { print $2 }' "$tree_entry_file") || return 2
    head_blob_oid=$(awk 'NR == 1 { print $3 }' "$tree_entry_file") || return 2
    case "$head_blob_mode $head_blob_type" in
        '100644 blob'|'100755 blob') ;;
        '120000 blob') return 3 ;;
        *) return 2 ;;
    esac

    git cat-file blob "$head_blob_oid" >"$head_blob_output" || return 2
}

node_workspace_contains() {
    workspace_scope_dir=$1
    workspace_package_dir=$2
    workspace_manifest=$(path_join "$workspace_scope_dir" 'package.json')
    workspace_manifest_status=0
    path_file_contains "$tracked_file" "$workspace_manifest" ||
        workspace_manifest_status=$?
    case $workspace_manifest_status in
        0) ;;
        1) return 1 ;;
        *) return 4 ;;
    esac

    workspace_blob_status=0
    head_blob_to_file "$workspace_manifest" "$version_blob_file" ||
        workspace_blob_status=$?
    [ "$workspace_blob_status" -eq 0 ] || return 4

    case $workspace_scope_dir in
        .) workspace_relative_dir=$workspace_package_dir ;;
        *)
            case $workspace_package_dir in
                "$workspace_scope_dir"/*)
                    workspace_relative_dir=${workspace_package_dir#"$workspace_scope_dir"/}
                    ;;
                *) return 1 ;;
            esac
            ;;
    esac

    command -v node >/dev/null 2>&1 || return 127
    node -e '
        const fs = require("fs");
        const relative = process.argv[1];
        let parsed;
        try {
            parsed = JSON.parse(fs.readFileSync(0, "utf8"));
        } catch (_) {
            process.exit(2);
        }
        let patterns = parsed && parsed.workspaces;
        if (patterns && !Array.isArray(patterns)) patterns = patterns.packages;
        if (!Array.isArray(patterns)) process.exit(1);

        function compile(pattern) {
            if (typeof pattern !== "string" || pattern.length === 0) return null;
            pattern = pattern.replace(/^\.\//, "").replace(/\/$/, "");
            if (/^[!]/.test(pattern) || /[{}\[\]]/.test(pattern)) return null;
            let source = "^";
            for (let index = 0; index < pattern.length; index += 1) {
                const character = pattern[index];
                if (character === "*" && pattern[index + 1] === "*") {
                    if (pattern[index + 2] === "/") {
                        source += "(?:.*/)?";
                        index += 2;
                    } else {
                        source += ".*";
                        index += 1;
                    }
                } else if (character === "*") {
                    source += "[^/]*";
                } else if (character === "?") {
                    source += "[^/]";
                } else {
                    source += character.replace(/[\\^$.*+?()[\]{}|]/g, "\\$&");
                }
            }
            return new RegExp(source + "$");
        }

        const matchers = patterns.map(compile);
        if (matchers.some((matcher) => matcher === null)) process.exit(3);
        process.exit(matchers.some((matcher) => matcher.test(relative)) ? 0 : 1);
    ' "$workspace_relative_dir" <"$version_blob_file"
}

node_dependency_fields_changed() {
    dependency_manifest_path=$1
    [ -n "$comparison_base" ] || return 0
    command -v node >/dev/null 2>&1 || return 2

    dependency_head_status=0
    head_blob_to_file "$dependency_manifest_path" "$version_blob_file" ||
        dependency_head_status=$?
    [ "$dependency_head_status" -eq 0 ] || return 2

    : >"$baseline_blob_file"
    git show "$comparison_base:$dependency_manifest_path" >"$baseline_blob_file" 2>/dev/null ||
        return 0

    node -e '
        const fs = require("fs");
        const fields = [
            "name", "version", "dependencies", "devDependencies", "peerDependencies",
            "peerDependenciesMeta", "optionalDependencies", "bundledDependencies",
            "bundleDependencies", "dependenciesMeta", "overrides", "resolutions", "pnpm",
            "engines", "os", "cpu", "libc", "packageManager", "workspaces"
        ];
        function normalize(value) {
            if (Array.isArray(value)) return value.map(normalize);
            if (value !== null && typeof value === "object") {
                const result = {};
                for (const key of Object.keys(value).sort()) result[key] = normalize(value[key]);
                return result;
            }
            return value;
        }
        function fingerprint(path) {
            const parsed = JSON.parse(fs.readFileSync(path, "utf8"));
            if (parsed === null || Array.isArray(parsed) || typeof parsed !== "object") {
                throw new Error("package.json root is not an object");
            }
            const selected = {};
            for (const field of fields) {
                if (Object.prototype.hasOwnProperty.call(parsed, field)) {
                    selected[field] = normalize(parsed[field]);
                }
            }
            return JSON.stringify(selected);
        }
        let head;
        let base;
        try {
            head = fingerprint(process.argv[1]);
            base = fingerprint(process.argv[2]);
        } catch (_) {
            process.exit(2);
        }
        process.exit(head === base ? 1 : 0);
    ' "$version_blob_file" "$baseline_blob_file"
}

collect_nearest_node_locks() {
    node_manifest_scope_dir=$1
    node_scope_dir=$node_manifest_scope_dir
    while :; do
        node_scope_found=0
        for node_lock_name in package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock; do
            node_lock_candidate=$(path_join "$node_scope_dir" "$node_lock_name")
            node_contains_status=0
            path_file_contains "$tracked_file" "$node_lock_candidate" ||
                node_contains_status=$?
            case $node_contains_status in
                0)
                    node_scope_found=1
                    ;;
                1) ;;
                *) return 3 ;;
            esac
        done
        if [ "$node_scope_found" -ne 0 ]; then
            if [ "$node_scope_dir" != "$node_manifest_scope_dir" ]; then
                node_workspace_status=0
                node_workspace_contains "$node_scope_dir" "$node_manifest_scope_dir" ||
                    node_workspace_status=$?
                case $node_workspace_status in
                    0) ;;
                    1) return 1 ;;
                    *) return 4 ;;
                esac
            fi
            for node_lock_name in package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock; do
                node_lock_candidate=$(path_join "$node_scope_dir" "$node_lock_name")
                node_contains_status=0
                path_file_contains "$tracked_file" "$node_lock_candidate" ||
                    node_contains_status=$?
                case $node_contains_status in
                    0) printf '%s\n' "$node_lock_candidate" ;;
                    1) ;;
                    *) return 3 ;;
                esac
            done
            return 0
        fi
        [ "$node_scope_dir" != '.' ] || return 1
        node_scope_dir=$(path_dirname "$node_scope_dir")
    done
}

node_scope_has_manifest() {
    node_manifest_search_dir=$1
    while IFS= read -r node_manifest_search_path; do
        case $node_manifest_search_dir in
            .)
                case $node_manifest_search_path in
                    package.json|*/package.json) return 0 ;;
                esac
                ;;
            *)
                case $node_manifest_search_path in
                    "$node_manifest_search_dir"/package.json|"$node_manifest_search_dir"/*/package.json)
                        return 0
                        ;;
                esac
                ;;
        esac
    done <"$tracked_file"
    return 1
}

extract_package_version() {
    command -v node >/dev/null 2>&1 || return 127
    node -e '
        const fs = require("fs");
        let parsed;
        try {
            parsed = JSON.parse(fs.readFileSync(0, "utf8"));
        } catch (_) {
            process.exit(2);
        }
        if (
            parsed === null ||
            Array.isArray(parsed) ||
            typeof parsed !== "object" ||
            !Object.prototype.hasOwnProperty.call(parsed, "version") ||
            typeof parsed.version !== "string" ||
            parsed.version.length === 0 ||
            /[\u0000\r\n]/.test(parsed.version)
        ) {
            process.exit(1);
        }
        process.stdout.write(parsed.version + "\n");
    ' <"$1"
}

extract_plain_version() {
    awk '
        /^[[:space:]]*$/ { next }
        {
            line = $0
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (value == "") value = line
            else multiple = 1
        }
        END {
            if (!multiple && value != "") print value
        }
    ' "$1"
}

extract_plist_version() {
    plist_query "$1" field CFBundleShortVersionString
}

extract_plist_build_number() {
    plist_query "$1" field CFBundleVersion
}

plist_has_bundle_version_key() {
    plist_query "$1" has-version ""
}

extract_pbx_versions() {
    awk '
        function strip_block_comments(value, result, start, rest, finish) {
            result = ""
            while (1) {
                if (in_block_comment) {
                    finish = index(value, "*/")
                    if (finish == 0) return ""
                    value = substr(value, finish + 2)
                    in_block_comment = 0
                }
                start = index(value, "/*")
                if (start == 0) return result value
                result = result substr(value, 1, start - 1)
                rest = substr(value, start + 2)
                finish = index(rest, "*/")
                if (finish == 0) {
                    in_block_comment = 1
                    return result
                }
                value = substr(rest, finish + 2)
            }
        }
        {
            line = strip_block_comments($0)
        }
        line ~ /^[[:space:]]*MARKETING_VERSION[[:space:]]*=/ {
            sub(/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*/, "", line)
            sub(/;.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            first = substr(line, 1, 1)
            last = substr(line, length(line), 1)
            single_quote = sprintf("%c", 39)
            if (length(line) >= 2 &&
                ((first == "\"" && last == "\"") ||
                 (first == single_quote && last == single_quote))) {
                line = substr(line, 2, length(line) - 2)
            }
            if (line != "") print line
        }
    ' "$1" | LC_ALL=C sort -u
}

extract_pbx_build_numbers() {
    awk '
        function strip_block_comments(value, result, start, rest, finish) {
            result = ""
            while (1) {
                if (in_block_comment) {
                    finish = index(value, "*/")
                    if (finish == 0) return ""
                    value = substr(value, finish + 2)
                    in_block_comment = 0
                }
                start = index(value, "/*")
                if (start == 0) return result value
                result = result substr(value, 1, start - 1)
                rest = substr(value, start + 2)
                finish = index(rest, "*/")
                if (finish == 0) {
                    in_block_comment = 1
                    return result
                }
                value = substr(rest, finish + 2)
            }
        }
        {
            line = strip_block_comments($0)
        }
        line ~ /^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/ {
            sub(/^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=[[:space:]]*/, "", line)
            sub(/;.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            first = substr(line, 1, 1)
            last = substr(line, length(line), 1)
            single_quote = sprintf("%c", 39)
            if (length(line) >= 2 &&
                ((first == "\"" && last == "\"") ||
                 (first == single_quote && last == single_quote))) {
                line = substr(line, 2, length(line) - 2)
            }
            if (line != "") print line
        }
    ' "$1" | LC_ALL=C sort -u
}

is_apple_build_number() {
    printf '%s\n' "$1" | grep -E '^[0-9]+(\.[0-9]+){0,2}$' >/dev/null 2>&1
}

is_apple_marketing_version() {
    printf '%s\n' "$1" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null 2>&1
}

extract_maven_version() {
    awk '
        { data = data $0 }
        END {
            original = data
            while (match(data, /<parent([[:space:]][^>]*)?>/)) {
                before_parent = substr(data, 1, RSTART - 1)
                after_parent = substr(data, RSTART + RLENGTH)
                if (!match(after_parent, /<\/parent>/)) break
                data = before_parent substr(after_parent, RSTART + RLENGTH)
            }

            boundary = length(data) + 1
            section_count = split("dependencies dependencyManagement build properties modules profiles reporting", sections, " ")
            for (section_index = 1; section_index <= section_count; section_index++) {
                section_position = index(data, "<" sections[section_index])
                if (section_position > 0 && section_position < boundary) boundary = section_position
            }
            project_header = substr(data, 1, boundary - 1)
            if (match(project_header, /<version>[[:space:]]*[^<]+[[:space:]]*<\/version>/)) {
                value = substr(project_header, RSTART, RLENGTH)
                sub(/^<version>[[:space:]]*/, "", value)
                sub(/[[:space:]]*<\/version>$/, "", value)
            } else if (match(original, /<parent([[:space:]][^>]*)?>/)) {
                parent_block = substr(original, RSTART + RLENGTH)
                if (match(parent_block, /<\/parent>/)) parent_block = substr(parent_block, 1, RSTART - 1)
                if (match(parent_block, /<version>[[:space:]]*[^<]+[[:space:]]*<\/version>/)) {
                    value = substr(parent_block, RSTART, RLENGTH)
                    sub(/^<version>[[:space:]]*/, "", value)
                    sub(/[[:space:]]*<\/version>$/, "", value)
                }
            }
            if (value == "${revision}" && match(original, /<revision>[[:space:]]*[^<]+[[:space:]]*<\/revision>/)) {
                    value = substr(original, RSTART, RLENGTH)
                    sub(/^<revision>[[:space:]]*/, "", value)
                    sub(/[[:space:]]*<\/revision>$/, "", value)
            }
            if (value != "") print value
        }
    ' "$1"
}

extract_gradle_version() {
    awk '
        /^[[:space:]]*version[[:space:]]*(=|[[:space:]])/ {
            line = $0
            sub(/^[[:space:]]*version[[:space:]]*=?[[:space:]]*/, "", line)
            sub(/[[:space:]]*;.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            quote = sprintf("%c", 39)
            first = substr(line, 1, 1)
            last = substr(line, length(line), 1)
            if ((first == "\"" && last == "\"") || (first == quote && last == quote)) {
                line = substr(line, 2, length(line) - 2)
            }
            if (line != "") {
                print line
                exit
            }
        }
    ' "$1"
}

extract_properties_version() {
    awk -F '=' '
        /^[[:space:]]*version[[:space:]]*=/ {
            value = $0
            sub(/^[^=]*=[[:space:]]*/, "", value)
            sub(/[[:space:]]*$/, "", value)
            print value
            exit
        }
    ' "$1"
}

das_print_rule
printf '发布检查\n'
das_print_rule
das_print_key_value "仓库" "$repo_root"
das_print_key_value "严格模式" "$strict"

shallow_repository=""
shallow_status=0
shallow_repository=$(git rev-parse --is-shallow-repository 2>/dev/null) || shallow_status=$?
case $shallow_status:$shallow_repository in
    0:false) das_ok "仓库具有完整的本地历史边界。" ;;
    0:true) add_unknown "当前是 shallow clone，无法可靠识别上一发布 Tag 或版本历史；获取足够历史与 Tags 后重新检查。" ;;
    *) add_blocker "无法判断仓库是否为 shallow clone；按 fail-closed 处理。" ;;
esac

das_git_status_file "$status_file" || das_die 4 "无法读取工作区状态。"
if [ -s "$status_file" ]; then
    add_blocker "工作区不干净；发布输入必须可复现。"
    das_print_excerpt "$status_file" 30
else
    das_ok "工作区干净。"
fi

if git diff --name-only --diff-filter=U >"$misc_file"; then
    if [ -s "$misc_file" ]; then
        add_blocker "存在未解决冲突。"
        das_print_excerpt "$misc_file" 20
    else
        das_ok "未发现未解决冲突。"
    fi
else
    das_die 4 "无法检查未解决冲突。"
fi

git_dir=$(git rev-parse --git-dir) || das_die 4 "无法定位 Git 目录。"
if [ -f "$git_dir/MERGE_HEAD" ] || [ -d "$git_dir/rebase-merge" ] || \
   [ -d "$git_dir/rebase-apply" ] || [ -f "$git_dir/CHERRY_PICK_HEAD" ] || \
   [ -f "$git_dir/REVERT_HEAD" ]; then
    add_blocker "仓库存在未完成的 Git 操作。"
else
    das_ok "没有进行中的 merge、rebase、cherry-pick 或 revert。"
fi

branch=$(das_current_branch)
das_print_key_value "当前分支" "$branch"
case $branch in
    DETACHED) add_blocker "HEAD 处于 detached 状态，无法确认发布分支归属。" ;;
    main|master|release/*|hotfix/*) das_ok "分支名称符合常见发布分支策略。" ;;
    *) add_warning "当前分支不是 main、master、release/* 或 hotfix/*；请核对项目发布策略。" ;;
esac

upstream=$(das_upstream 2>/dev/null) || upstream=""
if [ -n "$upstream" ]; then
    das_print_key_value "上游分支" "$upstream"
    sync_counts=$(das_ahead_behind HEAD "$upstream") || sync_counts=""
    if [ -n "$sync_counts" ]; then
        ahead=$(printf '%s\n' "$sync_counts" | awk '{ print $1 + 0 }')
        behind=$(printf '%s\n' "$sync_counts" | awk '{ print $2 + 0 }')
        das_print_key_value "领先/落后" "$ahead / $behind"
        if [ "$behind" -gt 0 ]; then
            add_blocker "当前分支落后本地上游引用；刷新远端证据后重新分析。"
        fi
        if [ "$ahead" -gt 0 ]; then
            add_warning "存在尚未体现在本地上游引用中的提交；发布前需确认远端状态。"
        fi
    else
        add_blocker "无法比较 HEAD 与上游引用；按 fail-closed 处理。"
    fi
else
    add_unknown "当前分支未配置上游，无法检查远端同步关系。"
fi
das_info "同步结论只基于本地远端跟踪引用；本脚本未执行 fetch，引用新鲜度需由调用方证明。"

if ! git tag --points-at HEAD >"$tag_file"; then
    das_die 4 "无法读取 HEAD Tag。"
fi
latest_tag=$(git describe --tags --abbrev=0 HEAD 2>/dev/null) || latest_tag=""
previous_release_tag=""
if [ -s "$tag_file" ]; then
    if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
        previous_release_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null) ||
            previous_release_tag=""
    fi
else
    previous_release_tag=$latest_tag
fi

if [ -n "$base_ref" ]; then
    das_validate_ref "$base_ref" || das_die 5 "无法解析发布比较基线：$base_ref"
    base_commit=$(git rev-parse --verify "$base_ref^{commit}") ||
        das_die 5 "发布比较基线不是有效提交：$base_ref"
    head_commit=$(git rev-parse --verify 'HEAD^{commit}') || das_die 4 "无法解析 HEAD 提交。"
    [ "$base_commit" != "$head_commit" ] ||
        das_die 5 "发布比较基线必须是 HEAD 的严格祖先，不能与 HEAD 相同：$base_ref"
    merge_base=$(git merge-base "$base_commit" "$head_commit") ||
        das_die 5 "比较基线与 HEAD 没有共同祖先：$base_ref"
    if [ "$merge_base" != "$base_commit" ]; then
        das_die 5 "发布比较基线必须是 HEAD 的严格祖先：$base_ref"
    fi
    comparison_base=$base_ref
else
    comparison_base=""
    if [ -s "$tag_file" ]; then
        comparison_base=$previous_release_tag
    elif [ -n "$latest_tag" ]; then
        comparison_base=$latest_tag
    fi
fi

if [ -n "$comparison_base" ]; then
    git -c core.quotePath=false diff --no-renames --name-only \
        "$comparison_base...HEAD" >"$changed_file" ||
        das_die 5 "无法生成 $comparison_base...HEAD 的发布差异。"
    git -c core.quotePath=false diff --no-renames --name-only --diff-filter=D \
        "$comparison_base...HEAD" >"$deleted_file" ||
        das_die 5 "无法生成 $comparison_base...HEAD 的删除文件清单。"
    das_print_key_value "差异基线" "$comparison_base...HEAD"
else
    git -c core.quotePath=false ls-tree -r --name-only HEAD >"$changed_file" ||
        das_die 4 "无法生成首次发布的完整文件清单。"
    : >"$deleted_file"
    das_print_key_value "差异基线" "首次发布完整树"
    das_info "没有历史 Tag 或显式基线；本次把 HEAD 的全部跟踪文件作为发布范围。"
fi
das_print_key_value "发布变更文件" "$(das_count_lines "$changed_file")"

if ! git -c core.quotePath=false ls-tree -r --name-only HEAD >"$tracked_file"; then
    das_die 4 "无法读取 HEAD 文件清单。"
fi
quoted_path_status=0
LC_ALL=C grep '^"' "$tracked_file" >"$misc_file" || quoted_path_status=$?
case $quoted_path_status in
    0)
        add_blocker "仓库存在需 Git 转义的特殊路径；文本行协议无法安全覆盖，拒绝给出发布通过结论："
        das_print_excerpt "$misc_file" 20
        ;;
    1) ;;
    *) add_blocker "特殊路径检查失败；按 fail-closed 处理。" ;;
esac
quoted_changed_status=0
LC_ALL=C grep '^"' "$changed_file" >"$misc_file" || quoted_changed_status=$?
case $quoted_changed_status in
    0)
        add_blocker "发布差异中存在需 Git 转义的特殊路径；删除文件也不能绕过依赖与工程门禁："
        das_print_excerpt "$misc_file" 20
        ;;
    1) ;;
    *) add_blocker "发布差异特殊路径检查失败；按 fail-closed 处理。" ;;
esac

if git -c core.quotePath=false ls-tree -r HEAD >"$tree_entry_file"; then
    if awk '$1 == "160000" && $2 == "commit" {
        path = $0
        sub(/^[^\t]*\t/, "", path)
        print path
    }' "$tree_entry_file" >"$gitlink_file"; then
        if [ -s "$gitlink_file" ]; then
            add_unknown "HEAD 包含 submodule gitlink；本脚本不会递归扫描其内容，必须分别核对固定提交、URL、可取回性与子模块测试："
            das_print_excerpt "$gitlink_file" 20
        else
            das_ok "HEAD 不包含未递归审计的 submodule gitlink。"
        fi
    else
        add_blocker "无法分析 HEAD 中的 gitlink；按 fail-closed 处理。"
    fi
else
    add_blocker "无法读取 HEAD tree mode；按 fail-closed 处理。"
fi

if git -c core.quotePath=false ls-files -v >"$index_flags_file"; then
    if awk '/^[[:lower:]]/ { print }' "$index_flags_file" >"$hidden_index_file"; then
        if [ -s "$hidden_index_file" ]; then
            add_blocker "Git index 存在 assume-unchanged 标记，工作区状态可能被隐藏："
            das_print_excerpt "$hidden_index_file" 20
        fi
    else
        add_blocker "无法分析 Git index assume-unchanged 标记；按 fail-closed 处理。"
    fi

    if awk '/^S / { print }' "$index_flags_file" >"$misc_file"; then
        if [ -s "$misc_file" ]; then
            sparse_checkout=""
            sparse_status=0
            sparse_checkout=$(git config --bool core.sparseCheckout 2>/dev/null) ||
                sparse_status=$?
            if [ "$sparse_status" -eq 0 ] && [ "$sparse_checkout" = 'true' ]; then
                add_unknown "当前工作树启用了 sparse-checkout；S 标记可能来自稀疏规则，发布前应在完整 checkout 中复核工作区状态："
                das_print_excerpt "$misc_file" 20
            elif [ "$sparse_status" -le 1 ]; then
                add_blocker "Git index 存在非 sparse-checkout 的 skip-worktree 标记，工作区状态可能被隐藏："
                das_print_excerpt "$misc_file" 20
            else
                add_blocker "无法读取 sparse-checkout 配置；按 fail-closed 处理。"
            fi
        fi
    else
        add_blocker "无法分析 Git index skip-worktree 标记；按 fail-closed 处理。"
    fi

    if [ ! -s "$hidden_index_file" ] && [ ! -s "$misc_file" ]; then
        das_ok "Git index 未使用隐藏工作区变化的标记。"
    fi
else
    add_blocker "无法读取 Git index 标记；按 fail-closed 处理。"
fi

pending_pattern='TO''DO|FIX''ME'
pending_status=0
scan_repository_pattern "$pending_pattern" "未完成标记" "$pending_file" 1 || pending_status=$?
case $pending_status in
    0)
        add_warning "受检文件中发现未完成标记："
        das_print_excerpt "$pending_file" 20
        ;;
    1) das_ok "受检文件中未发现未完成标记。" ;;
    *) add_blocker "未完成标记扫描执行失败；按 fail-closed 处理。" ;;
esac

diagnostic_status=0
scan_repository_diagnostics "$diagnostic_file" || diagnostic_status=$?
case $diagnostic_status in
    0)
        add_warning "受检文件中发现目标 print、NSLog、console.log、debug 调用或启用型 debug 配置："
        das_print_excerpt "$diagnostic_file" 20
        ;;
    1) das_ok "受检文件中未发现目标诊断代码。" ;;
    *) add_blocker "诊断代码扫描执行失败；按 fail-closed 处理。" ;;
esac
if [ -s "$diagnostic_plist_unknown_file" ]; then
    add_unknown "部分 plist 无法结构化解析，或当前环境缺少 plist 解析器，无法排除启用型 debug 配置："
    das_print_excerpt "$diagnostic_plist_unknown_file" 20
fi

conflict_status=0
scan_repository_pattern '^(<<<<<<< |=======|>>>>>>> )' "冲突标记" "$conflict_file" 0 || conflict_status=$?
case $conflict_status in
    0)
        add_blocker "受检文件疑似残留冲突标记："
        das_print_excerpt "$conflict_file" 20
        ;;
    1) das_ok "受检文件中未发现冲突标记。" ;;
    *) add_blocker "冲突标记扫描执行失败；按 fail-closed 处理。" ;;
esac

podfile_count=$(count_paths '(^|/)Podfile$')
podlock_count=$(count_paths '(^|/)Podfile\.lock$')
package_count=$(count_paths '(^|/)package\.json$')
node_lock_count=$(count_paths '(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|npm-shrinkwrap\.json)$')
swift_manifest_count=$(count_paths '(^|/)Package\.swift$')
swift_lock_count=$(count_paths '(^|/)Package\.resolved$')
pbx_count=$(count_paths '(^|/)project\.pbxproj$')
pom_count=$(count_paths '(^|/)pom\.xml$')
gradle_manifest_count=$(count_paths '(^|/)(build\.gradle(\.kts)?|settings\.gradle(\.kts)?|gradle\.properties|gradle/libs\.versions\.toml)$')
gradle_lock_count=$(count_paths '(^|/)(gradle\.lockfile|gradle/dependency-locks/.*\.lockfile)$')

das_print_rule
printf '工程与依赖文件\n'
das_print_key_value "Podfile / Lock" "$podfile_count / $podlock_count"
das_print_key_value "package.json / Lock" "$package_count / $node_lock_count"
das_print_key_value "Package.swift / Resolved" "$swift_manifest_count / $swift_lock_count"
das_print_key_value "project.pbxproj" "$pbx_count"
das_print_key_value "Maven pom.xml" "$pom_count"
das_print_key_value "Gradle 清单 / Lock" "$gradle_manifest_count / $gradle_lock_count"

awk '
    /(^|\/)(Podfile|Podfile\.lock|package\.json|package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|yarn\.lock|Package\.swift|Package\.resolved)$/ {
        print
    }
' "$tracked_file" >"$version_source_file" ||
    add_blocker "无法提取 HEAD 依赖文件清单；按 fail-closed 处理。"
while IFS= read -r dependency_path; do
    [ -n "$dependency_path" ] || continue
    dependency_blob_status=0
    head_blob_to_file "$dependency_path" "$version_blob_file" ||
        dependency_blob_status=$?
    case $dependency_blob_status in
        0) ;;
        3) add_blocker "依赖 manifest/lock 不是 HEAD 中的普通文件，拒绝符号链接：$dependency_path" ;;
        *) add_blocker "无法读取 HEAD 中的依赖 manifest/lock；按 fail-closed 处理：$dependency_path" ;;
    esac
done <"$version_source_file"

pbx_changed=0
pom_changed=0
gradle_manifest_changed=0
gradle_lock_changed=0
changed_has '(^|/)project\.pbxproj$' && pbx_changed=1
changed_has '(^|/)pom\.xml$' && pom_changed=1
changed_has '(^|/)(build\.gradle(\.kts)?|settings\.gradle(\.kts)?|gradle\.properties|gradle/libs\.versions\.toml)$' && gradle_manifest_changed=1
changed_has '(^|/)(gradle\.lockfile|gradle/dependency-locks/.*\.lockfile)$' && gradle_lock_changed=1

# CocoaPods 必须在同一目录内配对，兄弟工程的锁文件不能互相抵消。
awk '/(^|\/)Podfile$/ { print }' "$changed_file" >"$version_source_file" ||
    add_blocker "无法提取 CocoaPods 变更清单；按 fail-closed 处理。"
while IFS= read -r pod_manifest_path; do
    [ -n "$pod_manifest_path" ] || continue
    pod_scope_dir=$(path_dirname "$pod_manifest_path")
    pod_lock_path=$(path_join "$pod_scope_dir" 'Podfile.lock')
    pod_pair_status=0
    path_file_contains "$changed_file" "$pod_lock_path" || pod_pair_status=$?
    case $pod_pair_status in
        0) ;;
        1) add_blocker "$pod_manifest_path 已变更，但同目录 $pod_lock_path 未随发布差异更新。" ;;
        *) add_blocker "无法核对 CocoaPods 变更配对；按 fail-closed 处理：$pod_manifest_path" ;;
    esac
done <"$version_source_file"

awk '/(^|\/)Podfile\.lock$/ { print }' "$changed_file" >"$misc_file" ||
    add_blocker "无法提取 CocoaPods 锁文件变更；按 fail-closed 处理。"
while IFS= read -r pod_lock_path; do
    [ -n "$pod_lock_path" ] || continue
    pod_scope_dir=$(path_dirname "$pod_lock_path")
    pod_manifest_path=$(path_join "$pod_scope_dir" 'Podfile')
    pod_deleted_status=0
    path_file_contains "$deleted_file" "$pod_lock_path" || pod_deleted_status=$?
    if [ "$pod_deleted_status" -eq 0 ]; then
        pod_manifest_tracked_status=0
        path_file_contains "$tracked_file" "$pod_manifest_path" ||
            pod_manifest_tracked_status=$?
        case $pod_manifest_tracked_status in
            0) add_blocker "$pod_lock_path 已删除，但 HEAD 仍跟踪同目录 ${pod_manifest_path}。" ;;
            1) ;;
            *) add_blocker "无法核对 CocoaPods 锁文件删除；按 fail-closed 处理：$pod_lock_path" ;;
        esac
        continue
    elif [ "$pod_deleted_status" -gt 1 ]; then
        add_blocker "无法读取删除文件清单；按 fail-closed 处理：$pod_lock_path"
        continue
    fi
    pod_pair_status=0
    path_file_contains "$changed_file" "$pod_manifest_path" || pod_pair_status=$?
    case $pod_pair_status in
        0) ;;
        1) add_warning "$pod_lock_path 单独变更，请确认不是无意的依赖解析漂移。" ;;
        *) add_blocker "无法核对 CocoaPods 锁文件变更；按 fail-closed 处理：$pod_lock_path" ;;
    esac
done <"$misc_file"

awk '/(^|\/)Podfile$/ { print }' "$tracked_file" >"$version_source_file" ||
    add_blocker "无法提取 HEAD 中的 CocoaPods 清单；按 fail-closed 处理。"
while IFS= read -r pod_manifest_path; do
    [ -n "$pod_manifest_path" ] || continue
    pod_scope_dir=$(path_dirname "$pod_manifest_path")
    pod_lock_path=$(path_join "$pod_scope_dir" 'Podfile.lock')
    pod_tracked_status=0
    path_file_contains "$tracked_file" "$pod_lock_path" || pod_tracked_status=$?
    case $pod_tracked_status in
        0) ;;
        1) add_warning "$pod_manifest_path 在 HEAD 中没有同目录 Podfile.lock，请确认项目锁定策略。" ;;
        *) add_blocker "无法核对 HEAD 中的 CocoaPods 文件；按 fail-closed 处理：$pod_manifest_path" ;;
    esac
done <"$version_source_file"

# Node workspace 以最近祖先目录中的唯一锁文件为 scope。
awk '/(^|\/)package\.json$/ { print }' "$changed_file" >"$node_owner_raw_file" ||
    add_blocker "无法提取 Node 清单变更；按 fail-closed 处理。"
: >"$node_owner_file"
while IFS= read -r node_manifest_path; do
    [ -n "$node_manifest_path" ] || continue
    node_manifest_dir=$(path_dirname "$node_manifest_path")
    node_manifest_deleted_status=0
    path_file_contains "$deleted_file" "$node_manifest_path" ||
        node_manifest_deleted_status=$?
    if [ "$node_manifest_deleted_status" -eq 0 ]; then
        node_deleted_pair_found=0
        for node_lock_name in package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock; do
            node_lock_path=$(path_join "$node_manifest_dir" "$node_lock_name")
            node_deleted_lock_status=0
            path_file_contains "$deleted_file" "$node_lock_path" ||
                node_deleted_lock_status=$?
            case $node_deleted_lock_status in
                0) node_deleted_pair_found=1 ;;
                1) ;;
                *)
                    add_blocker "无法核对 Node 文件成对删除；按 fail-closed 处理：$node_manifest_path"
                    node_deleted_pair_found=1
                    ;;
            esac
        done
        if [ "$node_deleted_pair_found" -eq 1 ]; then
            continue
        fi
    elif [ "$node_manifest_deleted_status" -gt 1 ]; then
        add_blocker "无法读取删除文件清单；按 fail-closed 处理：$node_manifest_path"
        continue
    fi
    : >"$misc_file"
    node_owner_status=0
    collect_nearest_node_locks "$node_manifest_dir" >"$misc_file" || node_owner_status=$?
    case $node_owner_status in
        0)
            node_owner_count=$(das_count_lines "$misc_file")
            if [ "$node_owner_count" -ne 1 ]; then
                add_blocker "$node_manifest_path 所属 scope 跟踪了多个 Node 锁文件，无法确定唯一包管理器："
                das_print_excerpt "$misc_file" 10
                continue
            fi
            node_lock_path=$(sed -n '1p' "$misc_file")
            printf '%s\n' "$node_lock_path" >>"$node_owner_file"
            node_pair_status=0
            path_file_contains "$changed_file" "$node_lock_path" || node_pair_status=$?
            case $node_pair_status in
                0) ;;
                1)
                    node_dependency_status=0
                    node_dependency_fields_changed "$node_manifest_path" ||
                        node_dependency_status=$?
                    case $node_dependency_status in
                        0) add_blocker "$node_manifest_path 的依赖相关字段已变更，但所属 scope 的 $node_lock_path 未随发布差异更新。" ;;
                        1) das_ok "$node_manifest_path 只修改了非依赖字段，所属 lock 无需制造无意义差异。" ;;
                        *) add_unknown "无法比较 $node_manifest_path 在基线与 HEAD 间的依赖字段，不能确认 $node_lock_path 是否需要更新。" ;;
                    esac
                    ;;
                *) add_blocker "无法核对 Node scope 变更；按 fail-closed 处理：$node_manifest_path" ;;
            esac
            ;;
        1) add_blocker "$node_manifest_path 已变更，但从其目录到仓库根目录都没有受支持的 Node 锁文件。" ;;
        *) add_blocker "无法解析 Node lock scope；按 fail-closed 处理：$node_manifest_path" ;;
    esac
done <"$node_owner_raw_file"

if LC_ALL=C sort -u "$node_owner_file" >"$node_owner_raw_file"; then
    awk '/(^|\/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|npm-shrinkwrap\.json)$/ { print }' \
        "$changed_file" >"$misc_file" ||
        add_blocker "无法提取 Node 锁文件变更；按 fail-closed 处理。"
    while IFS= read -r node_lock_path; do
        [ -n "$node_lock_path" ] || continue
        node_lock_deleted_status=0
        path_file_contains "$deleted_file" "$node_lock_path" ||
            node_lock_deleted_status=$?
        if [ "$node_lock_deleted_status" -eq 0 ]; then
            node_lock_scope_dir=$(path_dirname "$node_lock_path")
            if node_scope_has_manifest "$node_lock_scope_dir"; then
                add_blocker "$node_lock_path 已删除，但 HEAD 中仍存在由该目录承载的 package.json。"
            fi
            continue
        elif [ "$node_lock_deleted_status" -gt 1 ]; then
            add_blocker "无法读取删除文件清单；按 fail-closed 处理：$node_lock_path"
            continue
        fi
        node_owner_match_status=0
        path_file_contains "$node_owner_raw_file" "$node_lock_path" ||
            node_owner_match_status=$?
        case $node_owner_match_status in
            0) ;;
            1) add_warning "$node_lock_path 没有对应的 Node manifest 变更，请确认解析环境和包管理器版本。" ;;
            *) add_blocker "无法归并 Node lock scope；按 fail-closed 处理：$node_lock_path" ;;
        esac
    done <"$misc_file"
else
    add_blocker "无法归并 Node lock scope；按 fail-closed 处理。"
fi

# 纯 Swift Package 按 sibling 文件配对；Xcode workspace 的 resolved 变化单独提示。
swift_manifest_changed=0
swift_lock_changed=0
changed_has '(^|/)Package\.swift$' && swift_manifest_changed=1
changed_has '(^|/)Package\.resolved$' && swift_lock_changed=1
awk '/(^|\/)Package\.swift$/ { print }' "$changed_file" >"$version_source_file" ||
    add_blocker "无法提取 SwiftPM 清单变更；按 fail-closed 处理。"
while IFS= read -r swift_manifest_path; do
    [ -n "$swift_manifest_path" ] || continue
    swift_scope_dir=$(path_dirname "$swift_manifest_path")
    swift_lock_path=$(path_join "$swift_scope_dir" 'Package.resolved')
    swift_tracked_status=0
    path_file_contains "$tracked_file" "$swift_lock_path" || swift_tracked_status=$?
    case $swift_tracked_status in
        0)
            swift_pair_status=0
            path_file_contains "$changed_file" "$swift_lock_path" || swift_pair_status=$?
            case $swift_pair_status in
                0) ;;
                1) add_blocker "$swift_manifest_path 已变更，但同目录 $swift_lock_path 未随发布差异更新。" ;;
                *) add_blocker "无法核对 SwiftPM 变更配对；按 fail-closed 处理：$swift_manifest_path" ;;
            esac
            ;;
        1) add_warning "$swift_manifest_path 已变更，但 HEAD 未跟踪同目录 Package.resolved；请确认库项目锁定策略。" ;;
        *) add_blocker "无法核对 HEAD 中的 SwiftPM 文件；按 fail-closed 处理：$swift_manifest_path" ;;
    esac
done <"$version_source_file"

awk '/(^|\/)Package\.resolved$/ { print }' "$changed_file" >"$misc_file" ||
    add_blocker "无法提取 SwiftPM resolved 变更；按 fail-closed 处理。"
while IFS= read -r swift_lock_path; do
    [ -n "$swift_lock_path" ] || continue
    swift_scope_dir=$(path_dirname "$swift_lock_path")
    swift_manifest_path=$(path_join "$swift_scope_dir" 'Package.swift')
    swift_deleted_status=0
    path_file_contains "$deleted_file" "$swift_lock_path" || swift_deleted_status=$?
    if [ "$swift_deleted_status" -eq 0 ]; then
        swift_manifest_tracked_status=0
        path_file_contains "$tracked_file" "$swift_manifest_path" ||
            swift_manifest_tracked_status=$?
        case $swift_manifest_tracked_status in
            0) add_blocker "$swift_lock_path 已删除，但 HEAD 仍跟踪同目录 ${swift_manifest_path}。" ;;
            1) ;;
            *) add_blocker "无法核对 SwiftPM 锁文件删除；按 fail-closed 处理：$swift_lock_path" ;;
        esac
        continue
    elif [ "$swift_deleted_status" -gt 1 ]; then
        add_blocker "无法读取删除文件清单；按 fail-closed 处理：$swift_lock_path"
        continue
    fi
    swift_pair_status=0
    path_file_contains "$changed_file" "$swift_manifest_path" || swift_pair_status=$?
    case $swift_pair_status in
        0) ;;
        1) add_warning "$swift_lock_path 单独变更或由 Xcode workspace 管理；请核对依赖解析来源并执行对应 Scheme/Package 测试。" ;;
        *) add_blocker "无法核对 SwiftPM resolved 变更；按 fail-closed 处理：$swift_lock_path" ;;
    esac
done <"$misc_file"

if [ "$swift_manifest_changed" -eq 1 ] || [ "$swift_lock_changed" -eq 1 ]; then
    add_warning "SwiftPM 文件位于发布差异中，必须保存可重复的 resolve、build 与 test 证据。"
fi

if [ "$pbx_changed" -eq 1 ]; then
    add_warning "project.pbxproj 位于发布差异中，必须执行目标 Scheme 的构建验证。"
fi
if [ "$pom_changed" -eq 1 ]; then
    add_warning "pom.xml 位于发布差异中；Maven 没有统一锁文件，必须保存有效依赖树与构建测试证据。"
fi
if [ "$gradle_manifest_changed" -eq 1 ] && [ "$gradle_lock_count" -gt 0 ] && [ "$gradle_lock_changed" -eq 0 ]; then
    add_warning "Gradle 清单已变更但现有依赖锁未变化；请确认变更未影响已解析依赖。"
fi
if [ "$gradle_lock_changed" -eq 1 ] && [ "$gradle_manifest_changed" -eq 0 ]; then
    add_warning "Gradle 依赖锁单独变更，请确认解析环境与仓库来源。"
fi
if [ "$package_count" -gt 0 ] && [ "$node_lock_count" -eq 0 ]; then
    add_warning "仓库跟踪 package.json 但未检测到受支持的 Node 锁文件。"
fi

awk '
    /^VERSION$/ || /(^|\/)(package\.json|project\.pbxproj|Info\.plist|pom\.xml|build\.gradle(\.kts)?|gradle\.properties)$/ {
        print
    }
' "$tracked_file" >"$version_source_file"

awk '/(^|\/)[^\/]*Info\.plist$/ { print }' "$tracked_file" >"$misc_file"
while IFS= read -r plist_candidate_path; do
    [ -n "$plist_candidate_path" ] || continue
    case $plist_candidate_path in
        */Info.plist|Info.plist) continue ;;
    esac
    plist_candidate_blob_status=0
    head_blob_to_file "$plist_candidate_path" "$version_blob_file" ||
        plist_candidate_blob_status=$?
    case $plist_candidate_blob_status in
        0)
            plist_candidate_key_status=0
            plist_has_bundle_version_key "$version_blob_file" || plist_candidate_key_status=$?
            case $plist_candidate_key_status in
                0) printf '%s\n' "$plist_candidate_path" >>"$version_source_file" ;;
                1) ;;
                2|4|127)
                    printf '%s\n' "$plist_candidate_path" >>"$version_source_file"
                    ;;
                *)
                    add_blocker "无法判断自定义 Info.plist 是否包含 Bundle 版本键；按 fail-closed 处理：$plist_candidate_path"
                    printf '%s\n' "$plist_candidate_path" >>"$version_source_file"
                    ;;
            esac
            ;;
        *)
            printf '%s\n' "$plist_candidate_path" >>"$version_source_file"
            ;;
    esac
done <"$misc_file"

awk '/(^|\/)(project\.pbxproj|[^\/]*Info\.plist)$/ { print }' \
    "$version_source_file" >"$build_source_file"

: >"$version_file"
: >"$unresolved_version_file"
: >"$version_reference_file"
: >"$build_file"
: >"$unresolved_build_file"
: >"$build_reference_file"
while IFS= read -r version_path; do
    [ -n "$version_path" ] || continue
    version_blob_status=0
    head_blob_to_file "$version_path" "$version_blob_file" || version_blob_status=$?
    case $version_blob_status in
        0) ;;
        3)
            add_blocker "版本来源不是 HEAD 中的普通文件，拒绝跟随符号链接：$version_path"
            printf '%s\n' "$version_path" >>"$unresolved_version_file"
            continue
            ;;
        *)
            add_blocker "无法读取 HEAD 中的版本来源；按 fail-closed 处理：$version_path"
            printf '%s\n' "$version_path" >>"$unresolved_version_file"
            continue
            ;;
    esac

    : >"$misc_file"
    version_extract_status=0
    version_kind=generic
    case $version_path in
        */VERSION|VERSION)
            extract_plain_version "$version_blob_file" >"$misc_file" || version_extract_status=$?
            ;;
        */package.json|package.json)
            extract_package_version "$version_blob_file" >"$misc_file" 2>/dev/null ||
                version_extract_status=$?
            ;;
        */project.pbxproj|project.pbxproj)
            version_kind=apple_marketing
            extract_pbx_versions "$version_blob_file" >"$misc_file" || version_extract_status=$?
            ;;
        *Info.plist)
            version_kind=apple_marketing
            extract_plist_version "$version_blob_file" >"$misc_file" || version_extract_status=$?
            ;;
        */pom.xml|pom.xml)
            extract_maven_version "$version_blob_file" >"$misc_file" || version_extract_status=$?
            ;;
        */build.gradle|build.gradle|*/build.gradle.kts|build.gradle.kts)
            extract_gradle_version "$version_blob_file" >"$misc_file" || version_extract_status=$?
            ;;
        */gradle.properties|gradle.properties)
            extract_properties_version "$version_blob_file" >"$misc_file" || version_extract_status=$?
            ;;
    esac

    case $version_extract_status in
        0|1) ;;
        2)
            case $version_path in
                */package.json|package.json)
                    add_blocker "HEAD 中的 package.json 不是有效 JSON：$version_path"
                    ;;
                *Info.plist) ;;
                *) add_blocker "版本解析器执行失败；按 fail-closed 处理：$version_path" ;;
            esac
            ;;
        3)
            case $version_path in
                *Info.plist) add_blocker "iOS 公开版本在 plist 中必须使用 string 类型：$version_path" ;;
                *) add_blocker "版本字段类型无效；按 fail-closed 处理：$version_path" ;;
            esac
            ;;
        4) ;;
        127)
            case $version_path in
                */package.json|package.json)
                    add_unknown "检测到 package.json，但当前环境没有 node，无法读取顶层版本：$version_path"
                    ;;
                *Info.plist) ;;
                *) add_blocker "版本解析器不可用；按 fail-closed 处理：$version_path" ;;
            esac
            ;;
        *) add_blocker "版本解析器异常退出；按 fail-closed 处理：$version_path" ;;
    esac

    parsed_for_source=0
    version_reference_for_source=0
    version_unknown_reference_for_source=0
    while IFS= read -r version_value; do
        [ -n "$version_value" ] || continue
        case $version_value in
            '$(MARKETING_VERSION)'|'${MARKETING_VERSION}')
                version_reference_for_source=1
                continue
                ;;
            *'$('*) version_unknown_reference_for_source=1; continue ;;
            *'${'*) version_unknown_reference_for_source=1; continue ;;
        esac
        valid_version_status=0
        if [ "$version_kind" = apple_marketing ]; then
            is_apple_marketing_version "$version_value" || valid_version_status=$?
        else
            printf '%s\n' "$version_value" | grep -E '^[0-9][0-9A-Za-z._+-]*$' \
                >/dev/null 2>&1 || valid_version_status=$?
        fi
        if [ "$valid_version_status" -eq 0 ]; then
            printf '%s\t%s\n' "$version_path" "$version_value" >>"$version_file"
            parsed_for_source=1
        elif [ "$valid_version_status" -eq 1 ] && [ "$version_kind" = apple_marketing ]; then
            add_blocker "iOS 公开版本必须是三段纯数字（Major.Minor.Patch）：$version_path"
        elif [ "$valid_version_status" -gt 1 ]; then
            add_blocker "版本格式校验命令执行失败；按 fail-closed 处理。"
        fi
    done <"$misc_file"
    if [ "$parsed_for_source" -eq 0 ]; then
        if [ "$version_unknown_reference_for_source" -eq 1 ]; then
            printf '%s\n' "$version_path" >>"$unresolved_version_file"
        elif [ "$version_reference_for_source" -eq 1 ]; then
            printf '%s\n' "$version_path" >>"$version_reference_file"
        else
            printf '%s\n' "$version_path" >>"$unresolved_version_file"
        fi
    fi

    case $version_path in
        */project.pbxproj|project.pbxproj)
            : >"$misc_file"
            extract_pbx_build_numbers "$version_blob_file" >"$misc_file" ||
                add_blocker "iOS build number 解析器执行失败；按 fail-closed 处理：$version_path"
            ;;
        *Info.plist)
            : >"$misc_file"
            build_extract_status=0
            extract_plist_build_number "$version_blob_file" >"$misc_file" ||
                build_extract_status=$?
            case $build_extract_status in
                0|1|2|4|127) ;;
                3) add_blocker "iOS build number 在 plist 中必须使用 string 类型：$version_path" ;;
                *) add_blocker "iOS build number 解析器执行失败；按 fail-closed 处理：$version_path" ;;
            esac
            ;;
        *) continue ;;
    esac

    build_parsed_for_source=0
    build_reference_for_source=0
    build_unknown_reference_for_source=0
    while IFS= read -r build_value; do
        [ -n "$build_value" ] || continue
        case $build_value in
            '$(CURRENT_PROJECT_VERSION)'|'${CURRENT_PROJECT_VERSION}')
                build_reference_for_source=1
                continue
                ;;
            *'$('*) build_unknown_reference_for_source=1; continue ;;
            *'${'*) build_unknown_reference_for_source=1; continue ;;
        esac
        build_validation_status=0
        is_apple_build_number "$build_value" || build_validation_status=$?
        case $build_validation_status in
            0)
                printf '%s\t%s\n' "$version_path" "$build_value" >>"$build_file"
                build_parsed_for_source=1
                ;;
            1)
                add_blocker "iOS build number 不是一至三段数字：$version_path"
                ;;
            *) add_blocker "iOS build number 格式校验命令执行失败；按 fail-closed 处理。" ;;
        esac
    done <"$misc_file"
    if [ "$build_parsed_for_source" -eq 0 ]; then
        if [ "$build_unknown_reference_for_source" -eq 1 ]; then
            printf '%s\n' "$version_path" >>"$unresolved_build_file"
        elif [ "$build_reference_for_source" -eq 1 ]; then
            printf '%s\n' "$version_path" >>"$build_reference_file"
        else
            printf '%s\n' "$version_path" >>"$unresolved_build_file"
        fi
    fi
done <"$version_source_file"

awk -F '\t' 'NF >= 2 { print $2 }' "$version_file" | LC_ALL=C sort -u >"$version_value_file"
awk -F '\t' 'NF >= 2 { print $2 }' "$build_file" | LC_ALL=C sort -u >"$build_value_file"

das_print_rule
printf '版本与 Tag\n'
version_source_count=$(das_count_lines "$version_source_file")
version_entry_count=$(das_count_lines "$version_file")
unique_version_count=$(das_count_lines "$version_value_file")
das_print_key_value "版本来源文件" "$version_source_count"
das_print_key_value "有效版本记录" "$version_entry_count"
das_print_key_value "唯一版本值" "$unique_version_count"
if [ "$version_entry_count" -gt 0 ]; then
    das_print_excerpt "$version_file" 40
else
    add_unknown "未从 VERSION、package.json、Info.plist、MARKETING_VERSION、pom.xml 或 Gradle 配置识别到版本号。"
fi
if [ -s "$unresolved_version_file" ]; then
    add_unknown "部分版本来源未能解析；可能使用变量、继承值、二进制 plist 或非标准格式："
    das_print_excerpt "$unresolved_version_file" 30
fi
if [ -s "$version_reference_file" ]; then
    add_unknown "marketing version 使用标准变量引用；静态扫描无法证明 Info.plist、具体 target、configuration 与 project.pbxproj/xcconfig 候选值的对应关系："
    das_print_excerpt "$version_reference_file" 30
fi
if [ "$unique_version_count" -gt 1 ]; then
    add_unknown "检测到多个版本值，可能属于 monorepo、多 App 或多模块；必须先明确本次发布 scope，再核对该 scope 的版本与 Tag："
    das_print_excerpt "$version_value_file" 20
fi

build_source_count=$(das_count_lines "$build_source_file")
if [ "$build_source_count" -gt 0 ]; then
    build_entry_count=$(das_count_lines "$build_file")
    unique_build_count=$(das_count_lines "$build_value_file")
    das_print_key_value "iOS 构建号来源" "$build_source_count"
    das_print_key_value "有效构建号记录" "$build_entry_count"
    das_print_key_value "唯一构建号值" "$unique_build_count"
    if [ "$build_entry_count" -gt 0 ]; then
        das_print_excerpt "$build_file" 40
    else
        add_unknown "检测到 iOS 版本来源，但未解析到 CFBundleVersion 或 CURRENT_PROJECT_VERSION。"
    fi
    if [ -s "$unresolved_build_file" ]; then
        add_unknown "部分 iOS build number 来源未能解析；可能缺失配置、使用变量或继承值："
        das_print_excerpt "$unresolved_build_file" 30
    fi
    if [ -s "$build_reference_file" ]; then
        add_unknown "iOS build number 使用标准变量引用；静态扫描无法证明 Info.plist、具体 target、configuration 与 project.pbxproj/xcconfig 候选值的对应关系："
        das_print_excerpt "$build_reference_file" 30
    fi
    if [ "$unique_build_count" -gt 1 ]; then
        add_unknown "检测到多个 iOS build number；必须明确 App、Extension 与发布 scope 后核对一致性："
        das_print_excerpt "$build_file" 40
    elif [ "$unique_build_count" -eq 1 ]; then
        das_ok "已识别唯一 iOS build number：$(sed -n '1p' "$build_value_file")。"
    fi
fi

if [ -n "$latest_tag" ]; then
    das_print_key_value "最近可达 Tag" "$latest_tag"
else
    add_unknown "仓库没有可达 Tag，无法核对版本发布历史。"
fi

if [ -n "$previous_release_tag" ]; then
    das_print_key_value "上一发布 Tag" "$previous_release_tag"
    if [ "$unique_version_count" -eq 1 ]; then
        current_version=$(sed -n '1p' "$version_value_file")
        case $previous_release_tag in
            v*|V*) previous_version=${previous_release_tag#?} ;;
            *) previous_version=$previous_release_tag ;;
        esac
        version_order=""
        version_compare_status=0
        version_order=$(das_semver_compare "$current_version" "$previous_version") ||
            version_compare_status=$?
        case $version_compare_status in
            0)
                case $version_order in
                    1) das_ok "候选版本 $current_version 高于上一发布版本 ${previous_version}。" ;;
                    0|-1)
                        add_blocker "候选版本 $current_version 未高于上一发布版本 ${previous_version}（${previous_release_tag}）。"
                        ;;
                    *) add_blocker "版本比较器返回了无法识别的结果；按 fail-closed 处理。" ;;
                esac
                ;;
            2)
                add_unknown "无法按 Semantic Versioning 比较候选版本 $current_version 与上一 Tag ${previous_release_tag}；必须依据项目版本策略人工核对。"
                ;;
            *) add_blocker "版本比较执行失败；按 fail-closed 处理。" ;;
        esac
    fi
else
    das_info "未发现上一发布 Tag；按首次发布处理，不执行版本递增比较。"
fi

if [ -s "$tag_file" ]; then
    das_print_key_value "HEAD Tag" "$(tr '\n' ' ' <"$tag_file")"
    if [ "$unique_version_count" -eq 1 ]; then
        while IFS= read -r version_value; do
            [ -n "$version_value" ] || continue
            tag_match_status=1
            grep -F -x "$version_value" "$tag_file" >/dev/null 2>&1 && tag_match_status=0
            if [ "$tag_match_status" -ne 0 ]; then
                grep -F -x "v$version_value" "$tag_file" >/dev/null 2>&1 && tag_match_status=0
            fi
            if [ "$tag_match_status" -ne 0 ]; then
                add_blocker "HEAD Tag 与版本 $version_value 不匹配（允许 v 前缀）。"
            fi
        done <"$version_value_file"
    fi
else
    add_unknown "HEAD 尚未打 Tag；若这是打标前预检，创建 Tag 后必须再次运行检查。"
fi

das_print_rule
effective_blockers=$blockers
if [ "$strict" -eq 1 ]; then
    effective_blockers=$((effective_blockers + warnings + unknowns))
fi
das_print_key_value "阻断项" "$blockers"
das_print_key_value "警告项" "$warnings"
das_print_key_value "未知项" "$unknowns"
if [ "$strict" -eq 1 ]; then
    das_print_key_value "严格模式阻断总数" "$effective_blockers"
fi

if [ "$effective_blockers" -gt 0 ]; then
    printf '是否允许发布：否\n'
    das_error "修复阻断项后，应重新运行检查与项目实际构建/测试。"
    exit 1
fi

if [ "$unknowns" -gt 0 ]; then
    printf '是否允许发布：有条件允许\n'
    das_warn "静态门禁没有硬阻断，但未知证据尚未闭环；返回非零退出码，禁止自动化流程把它当作通过。"
    exit 1
fi

if [ "$warnings" -gt 0 ]; then
    printf '是否允许发布：有条件允许\n'
    das_warn "静态门禁没有硬阻断，但已知警告仍需人工接受并完成实际构建与回归。"
    exit 0
fi

printf '是否允许发布：是\n'
das_ok "静态发布检查通过；本结论不替代构建、签名、真机、服务端或部署验证。"
