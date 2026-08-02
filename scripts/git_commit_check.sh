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
用法：git_commit_check.sh

对暂存区执行只读提交前检查：
  - 未解决冲突与冲突标记
  - Git whitespace 错误
  - 凭据、证书和私钥类文件名
  - 大文件与二进制文件
  - 新增的未完成标记和调试输出
  - 高风险工程配置与依赖锁文件

脚本不会执行 git add 或 git commit。
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

git diff --cached --quiet --exit-code
cached_diff_status=$?
case $cached_diff_status in
    0) das_die 4 "暂存区没有可提交变更。请先审查工作区差异，再明确执行 git add。" ;;
    1) ;;
    *) das_die 4 "无法读取暂存区差异。" ;;
esac

status_file=""
names_file=""
check_file=""
marker_file=""
diff_file=""
pending_file=""
diagnostic_file=""
secret_file=""
cleanup() {
    das_cleanup_files "$status_file" "$names_file" "$check_file" "$marker_file" \
        "$diff_file" "$pending_file" "$diagnostic_file" "$secret_file"
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
names_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
check_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
marker_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
diff_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
pending_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
diagnostic_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"
secret_file=$(das_make_temp_file) || das_die 4 "无法创建临时文件。"

if ! git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR >"$names_file"; then
    das_die 4 "无法读取暂存文件清单。"
fi
blockers=0
warnings=0

das_print_rule
printf 'Git 提交前检查\n'
das_print_rule
if ! git -c core.quotePath=false diff --cached --stat --compact-summary; then
    das_die 4 "无法生成暂存差异统计。"
fi

if git diff --name-only --diff-filter=U >"$status_file"; then
    if [ -s "$status_file" ]; then
        blockers=$((blockers + 1))
        das_error "存在未解决冲突："
        das_print_excerpt "$status_file" 20
    else
        das_ok "未发现未解决冲突。"
    fi
else
    das_die 4 "无法检查未解决冲突。"
fi

if git diff --cached --check >"$check_file" 2>&1; then
    das_ok "未发现 whitespace 错误。"
else
    blockers=$((blockers + 1))
    das_error "暂存内容包含 whitespace 错误："
    awk '
        match($0, /:[0-9]+:/) {
            print substr($0, 1, RSTART + RLENGTH - 1) " [问题内容已脱敏]"
        }
    ' "$check_file" >"$status_file"
    das_print_excerpt "$status_file" 20
fi

grep_status=0
git grep --cached -n -I -E '^(<<<<<<< |=======|>>>>>>> )' -- . >"$marker_file" 2>/dev/null || grep_status=$?
if [ "$grep_status" -eq 0 ] && [ -s "$marker_file" ]; then
    blockers=$((blockers + 1))
    das_error "暂存内容疑似包含冲突标记："
    awk '
        match($0, /:[0-9]+:/) {
            print substr($0, 1, RSTART + RLENGTH - 1) " [冲突标记内容已脱敏]"
        }
    ' "$marker_file" >"$status_file"
    das_print_excerpt "$status_file" 20
elif [ "$grep_status" -gt 1 ]; then
    blockers=$((blockers + 1))
    das_error "无法完成暂存内容的冲突标记扫描；按 fail-closed 处理。"
else
    das_ok "未发现冲突标记。"
fi

suspicious_path_status=0
LC_ALL=C grep '^"' "$names_file" >"$check_file" || suspicious_path_status=$?
if [ "$suspicious_path_status" -eq 0 ]; then
    blockers=$((blockers + 1))
    das_error "暂存路径包含换行、Tab、引号或其他需 Git 转义的字符；为防止路径门禁绕过，拒绝继续："
    das_print_excerpt "$check_file" 20
elif [ "$suspicious_path_status" -gt 1 ]; then
    das_die 4 "无法检查特殊暂存路径。"
fi

sensitive_pattern='(^|/)(\.env($|\.)|\.npmrc$|\.netrc$|GoogleService-Info\.plist$|google-services\.json$|.*\.(pem|key|p12|pfx|keystore|jks|mobileprovision)$|id_(rsa|ed25519)$|credentials?(\.|$)|secrets?(\.|$))'
sensitive_status=0
grep -E -i "$sensitive_pattern" "$names_file" >"$check_file" || sensitive_status=$?
if [ "$sensitive_status" -eq 0 ]; then
    blockers=$((blockers + 1))
    das_error "暂存区包含可能承载凭据、证书或私钥的文件："
    das_print_excerpt "$check_file" 20
elif [ "$sensitive_status" -gt 1 ]; then
    blockers=$((blockers + 1))
    das_error "敏感文件名扫描失败；按 fail-closed 处理。"
else
    das_ok "未发现高敏感文件名。"
fi

large_warning=0
large_blocker=0
if ! git diff --cached --numstat >"$status_file"; then
    das_die 4 "无法读取暂存文件体积统计。"
fi
binary_count=$(awk '$1 == "-" || $2 == "-" { count++ } END { print count + 0 }' "$status_file")
: >"$check_file"
while IFS= read -r staged_path; do
    [ -n "$staged_path" ] || continue
    case $staged_path in
        \"*) continue ;;
    esac
    staged_size=$(git cat-file -s ":./$staged_path" 2>/dev/null) || {
        blockers=$((blockers + 1))
        printf '%s\n' "$staged_path [无法读取暂存对象大小]" >>"$check_file"
        continue
    }
    if das_is_integer "$staged_size"; then
        if [ "$staged_size" -ge 52428800 ]; then
            large_blocker=$((large_blocker + 1))
            printf '%s\t%s bytes\n' "$staged_path" "$staged_size" >>"$check_file"
        elif [ "$staged_size" -ge 5242880 ]; then
            large_warning=$((large_warning + 1))
        fi
    fi
done <"$names_file"
if [ "$large_blocker" -gt 0 ]; then
    blockers=$((blockers + 1))
    das_error "发现至少 50 MiB 的暂存文件；请确认是否应使用 Git LFS："
    das_print_excerpt "$check_file" 20
elif [ "$large_warning" -gt 0 ]; then
    warnings=$((warnings + 1))
    das_warn "发现 $large_warning 个至少 5 MiB 的暂存文件，请确认体积与仓库存储策略。"
else
    das_ok "未发现超出体积阈值的暂存文件。"
fi
if grep -F '[无法读取暂存对象大小]' "$check_file" >/dev/null 2>&1; then
    das_error "部分暂存对象无法核验大小；按 fail-closed 处理："
    das_print_excerpt "$check_file" 20
fi
if [ "$binary_count" -gt 0 ]; then
    warnings=$((warnings + 1))
    das_warn "暂存区包含 $binary_count 个二进制文件，请确认来源、授权和体积。"
fi

if ! git -c core.quotePath=false diff --cached --unified=0 --no-color \
    --no-ext-diff --no-textconv >"$diff_file"; then
    das_die 4 "无法生成暂存内容安全扫描输入。"
fi

awk -v pending_out="$pending_file" -v diagnostic_out="$diagnostic_file" \
    -v secret_out="$secret_file" '
    function safe_placeholder(value, lower_value) {
        lower_value = tolower(value)
        return lower_value ~ /(redacted|example|sample|dummy|placeholder|changeme|not[_-]?a[_-]?secret|process\.env|system\.getenv|os\.getenv|\$\{|<[^>]*>)/
    }
    function secret_category(text, lower_text, upper_text, value, pem_head, pem_tail, gh_pat, gh_classic, stripe_live, slack_bot, slack_user, slack_app, bearer_label) {
        lower_text = tolower(text)
        upper_text = toupper(text)
        pem_head = "-----be" "gin "
        pem_tail = "private " "key-----"
        gh_pat = "github_" "pat_"
        gh_classic = "gh" "p_"
        stripe_live = "sk_" "live_"
        slack_bot = "xox" "b-"
        slack_user = "xox" "p-"
        slack_app = "xox" "a-"
        bearer_label = "Bearer" " Token"
        if (index(lower_text, pem_head) > 0 && index(lower_text, pem_tail) > 0) {
            return "私钥内容"
        }
        if (index(lower_text, gh_pat) > 0 || index(lower_text, gh_classic) > 0) {
            return "GitHub Token"
        }
        if (index(lower_text, stripe_live) > 0) {
            return "生产密钥前缀"
        }
        if (index(lower_text, slack_bot) > 0 || index(lower_text, slack_user) > 0 || index(lower_text, slack_app) > 0) {
            return "Slack Token"
        }
        if (upper_text ~ /AKIA[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]/) {
            return "AWS Access Key"
        }
        if (lower_text ~ /eyj[a-z0-9_-]+\.eyj[a-z0-9_-]+\.[a-z0-9_-]+/) {
            return "JWT"
        }
        if (lower_text ~ /bearer[[:space:]]+[a-z0-9._~+\/-]+/ && !safe_placeholder(lower_text)) {
            return bearer_label
        }
        if (lower_text ~ /[a-z][a-z0-9+.-]*:\/\/[^[:space:]\/:]+:[^[:space:]@]+@/ && !safe_placeholder(lower_text)) {
            return "含凭据的 DSN 或 URL"
        }
        value = lower_text
        if (sub(/^.*(api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|private[_-]?key|password|passwd|token|secret)[[:space:]\"]*[:=][[:space:]]*/, "", value)) {
            gsub(/^[[:space:]]+/, "", value)
            quote = sprintf("%c", 39)
            first = substr(value, 1, 1)
            quoted_literal = (first == "\"" || first == quote)
            if (quoted_literal) {
                value = substr(value, 2)
                closing = index(value, first)
                if (closing > 0) value = substr(value, 1, closing - 1)
            } else {
                sub(/[,;#[:space:]].*$/, "", value)
            }
            if (length(value) >= 8 && !safe_placeholder(value) && \
                (quoted_literal || (index(value, ".") == 0 && index(value, "(") == 0 && \
                index(value, "[") == 0 && index(value, "{") == 0))) {
                return "硬编码凭据候选"
            }
        }
        return ""
    }
    /^\+\+\+/ {
        file = $0
        sub(/^\+\+\+ b\//, "", file)
        next
    }
    /^@@ / {
        hunk = $0
        sub(/^@@ -[^ ]+ \+/, "", hunk)
        sub(/[, ].*$/, "", hunk)
        new_line = hunk + 0
        next
    }
    /^\+/ {
        content = substr($0, 2)
        upper_content = toupper(content)
        lower_content = tolower(content)
        if (upper_content ~ /TO[D]O|FIX[M]E/) {
            print file ":" new_line ": [未完成标记内容已脱敏]" > pending_out
        }
        if (lower_content ~ /(^|[^[:alnum:]_])(print[[:space:]]*\(|nslog[[:space:]]*\(|console\.log[[:space:]]*\(|debugprint[[:space:]]*\(|logger\.debug[[:space:]]*\(|debugger[[:space:]]*;|debug([^[:alnum:]_]|$))/) {
            print file ":" new_line ": [调试内容已脱敏]" > diagnostic_out
        }
        category = secret_category(content)
        if (category != "") {
            print file ":" new_line ": [" category "，内容已脱敏]" > secret_out
        }
        new_line++
        next
    }
    /^-/ { next }
    /^\\ No newline/ { next }
    { new_line++ }
' "$diff_file"
awk_scan_status=$?
if [ "$awk_scan_status" -ne 0 ]; then
    blockers=$((blockers + 1))
    das_error "暂存内容分类扫描失败；按 fail-closed 处理。"
fi

if [ -s "$pending_file" ]; then
    warnings=$((warnings + 1))
    das_warn "新增内容包含未完成标记："
    das_print_excerpt "$pending_file" 10
fi
if [ -s "$diagnostic_file" ]; then
    warnings=$((warnings + 1))
    das_warn "新增内容包含调试输出或断点语句："
    das_print_excerpt "$diagnostic_file" 10
fi
if [ -s "$secret_file" ]; then
    blockers=$((blockers + 1))
    das_error "新增内容包含高置信度凭据或私钥候选："
    das_print_excerpt "$secret_file" 20
fi

risk_pattern='(^|/)(Podfile(\.lock)?|package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|project\.pbxproj|pom\.xml|build\.gradle(\.kts)?|gradle\.lockfile)$'
risk_status=0
grep -E "$risk_pattern" "$names_file" >"$check_file" || risk_status=$?
if [ "$risk_status" -eq 0 ]; then
    warnings=$((warnings + 1))
    das_warn "暂存区包含工程配置或依赖文件，请确认配套文件和构建结果："
    das_print_excerpt "$check_file" 20
elif [ "$risk_status" -gt 1 ]; then
    blockers=$((blockers + 1))
    das_error "工程配置风险扫描失败；按 fail-closed 处理。"
fi

das_print_rule
das_print_key_value "阻断项" "$blockers"
das_print_key_value "警告项" "$warnings"
if [ "$blockers" -gt 0 ]; then
    printf '允许提交：否\n'
    das_error "请修复阻断项并重新执行检查。"
    exit 1
fi

printf '允许提交：是\n'
if [ "$warnings" -gt 0 ]; then
    das_warn "允许不代表已验证功能；请人工确认全部警告，并运行最小相关测试。"
else
    das_ok "暂存区通过静态提交前检查。"
fi
