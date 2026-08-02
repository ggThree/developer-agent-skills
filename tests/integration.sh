#!/bin/sh

set -u

TEST_DIR=$(CDPATH='' cd -P -- "$(dirname -- "$0")" && pwd) || exit 127
REPO_DIR=$(CDPATH='' cd -P -- "$TEST_DIR/.." && pwd) || exit 127
TEST_ROOT=""
TEST_COUNT=0
EXPECTED_TEST_COUNT=41

cleanup() {
    expected_tmp=${TMPDIR:-/tmp}
    case $TEST_ROOT in
        "$expected_tmp"/developer-agent-skills-tests.*) ;;
        '') return 0 ;;
        *)
            printf '%s\n' "[测试错误] 拒绝清理不可信路径：$TEST_ROOT" >&2
            return 1
            ;;
    esac
    if [ -d "$TEST_ROOT" ] && [ ! -L "$TEST_ROOT" ]; then
        find "$TEST_ROOT" -depth -type f -exec rm -f -- {} \;
        find "$TEST_ROOT" -depth -type l -exec rm -f -- {} \;
        find "$TEST_ROOT" -depth -type d -exec rmdir {} \;
    fi
}

on_signal() {
    signal_exit=$1
    trap - EXIT HUP INT TERM
    cleanup
    exit "$signal_exit"
}

fail() {
    printf '%s\n' "[测试失败] $*" >&2
    exit 1
}

pass() {
    TEST_COUNT=$((TEST_COUNT + 1))
    printf '%s\n' "[测试通过] $*"
}

expect_exit() {
    expected_status=$1
    captured_output=$2
    shift 2
    "$@" >"$captured_output" 2>&1
    actual_status=$?
    if [ "$actual_status" -ne "$expected_status" ]; then
        fail "期望退出码 ${expected_status}，实际为 ${actual_status}。"
    fi
}

run_in_repo() {
    target_repo=$1
    shift
    (
        cd "$target_repo" || exit 3
        "$@"
    )
}

init_repo() {
    target_repo=$1
    mkdir -p "$target_repo" || fail "无法创建测试仓库。"
    git -C "$target_repo" init -b main >/dev/null 2>&1 || fail "无法初始化测试仓库。"
}

commit_all() {
    target_repo=$1
    commit_subject=$2
    git -C "$target_repo" add -- . || fail "无法暂存测试夹具。"
    git -C "$target_repo" -c user.name='Integration Test' \
        -c user.email='integration@example.invalid' commit -m "$commit_subject" \
        >/dev/null 2>&1 || fail "无法提交测试夹具。"
}

configure_local_upstream() {
    upstream_repo=$1
    upstream_fixture=$2
    git -C "$upstream_repo" remote add origin "$TEST_ROOT/${upstream_fixture}-origin.git" ||
        fail "无法配置 ${upstream_fixture} 测试远端。"
    git -C "$upstream_repo" update-ref refs/remotes/origin/main HEAD ||
        fail "无法建立 ${upstream_fixture} 测试远端跟踪引用。"
    git -C "$upstream_repo" branch --set-upstream-to=origin/main main >/dev/null 2>&1 ||
        fail "无法配置 ${upstream_fixture} 测试上游。"
}

assert_release_blocked() {
    blocked_output=$1
    shift
    grep -E '阻断项[^0-9]*[1-9][0-9]*' "$blocked_output" >/dev/null 2>&1 ||
        fail "发布负例没有产生目标阻断项。"
    grep -F '是否允许发布：否' "$blocked_output" >/dev/null 2>&1 ||
        fail "发布负例没有形成拒绝发布结论。"
    for blocked_fragment in "$@"; do
        grep -F "$blocked_fragment" "$blocked_output" >/dev/null 2>&1 ||
            fail "发布负例诊断缺少目标证据：$blocked_fragment"
    done
}

assert_release_allowed() {
    allowed_output=$1
    grep -E '阻断项[^0-9]*0([^0-9]|$)' "$allowed_output" >/dev/null 2>&1 ||
        fail "发布正例仍包含阻断项。"
    grep -F '是否允许发布：是' "$allowed_output" >/dev/null 2>&1 ||
        fail "发布正例没有形成允许发布结论。"
}

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/developer-agent-skills-tests.XXXXXX") ||
    fail "无法创建测试根目录。"
trap cleanup EXIT
trap 'on_signal 129' HUP
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

help_output=$TEST_ROOT/help.out
for target_script in "$REPO_DIR"/scripts/*.sh; do
    [ -x "$target_script" ] || fail "脚本缺少可执行位：$target_script"
    expect_exit 0 "$help_output" "$target_script" --help
    grep -F '退出码：' "$help_output" >/dev/null 2>&1 ||
        fail "脚本帮助缺少退出码说明：$target_script"
done
pass "九个脚本均可直接执行并提供退出码说明"

clean_repo=$TEST_ROOT/clean-repo
init_repo "$clean_repo"
printf '%s\n' 'baseline' >"$clean_repo/tracked.txt"
commit_all "$clean_repo" 'test: 建立正常提交基线'
printf '%s\n' 'clean staged change' >"$clean_repo/staged.txt"
git -C "$clean_repo" add -- staged.txt || fail "无法暂存正常提交夹具。"
clean_commit_output=$TEST_ROOT/clean-commit.out
expect_exit 0 "$clean_commit_output" run_in_repo "$clean_repo" \
    "$REPO_DIR/scripts/git_commit_check.sh"
grep -F '允许提交：是' "$clean_commit_output" >/dev/null 2>&1 ||
    fail "普通暂存内容未通过提交前检查。"
pass "普通暂存内容可以通过提交前检查"

self_scan_repo=$TEST_ROOT/self-scan-repo
init_repo "$self_scan_repo"
cp "$REPO_DIR/scripts/git_commit_check.sh" "$self_scan_repo/git_commit_check.sh" ||
    fail "无法复制提交检查脚本自扫描夹具。"
git -C "$self_scan_repo" add -- git_commit_check.sh || fail "无法暂存提交检查脚本自扫描夹具。"
self_scan_output=$TEST_ROOT/self-scan.out
expect_exit 0 "$self_scan_output" run_in_repo "$self_scan_repo" \
    "$REPO_DIR/scripts/git_commit_check.sh"
grep -F '允许提交：是' "$self_scan_output" >/dev/null 2>&1 ||
    fail "提交检查脚本被自身规则误判。"
if grep -F '新增内容包含高置信度凭据或私钥候选' "$self_scan_output" >/dev/null 2>&1; then
    fail "提交检查脚本自扫描产生凭据误报。"
fi
pass "提交检查脚本首次入库时不会误判自身检测规则"

printf '%s\n' 'updated baseline' >"$clean_repo/tracked.txt"
printf '%s\n' 'untracked change' >"$clean_repo/untracked.txt"
changed_output=$TEST_ROOT/changed.out
expect_exit 0 "$changed_output" run_in_repo "$clean_repo" \
    "$REPO_DIR/scripts/git_changed_files.sh" --all --name-only
for expected_path in staged.txt tracked.txt untracked.txt; do
    grep -F -x "$expected_path" "$changed_output" >/dev/null 2>&1 ||
        fail "完整变更清单缺少路径：$expected_path"
done
pass "完整变更清单同时覆盖暂存、未暂存与未跟踪文件"

secret_repo=$TEST_ROOT/secret-repo
init_repo "$secret_repo"
printf '%s\n' 'baseline' >"$secret_repo/base.txt"
commit_all "$secret_repo" 'test: 建立秘密扫描基线'
jwt_header='eyJhbGciOiJIUzI1NiJ9'
jwt_payload='eyJzdWIiOiIxMjM0NTY3ODkwIn0'
jwt_signature='integration_signature'
jwt_value=$jwt_header.$jwt_payload.$jwt_signature
printf 'const token = "%s";\n' "$jwt_value" >"$secret_repo/token.js"
git -C "$secret_repo" add -- token.js || fail "无法暂存秘密扫描夹具。"
secret_output=$TEST_ROOT/secret.out
expect_exit 1 "$secret_output" run_in_repo "$secret_repo" \
    "$REPO_DIR/scripts/git_commit_check.sh"
grep -F '[JWT，内容已脱敏]' "$secret_output" >/dev/null 2>&1 ||
    fail "JWT 未被分类阻断。"
if grep -F "$jwt_value" "$secret_output" >/dev/null 2>&1; then
    fail "秘密扫描输出泄露了测试值。"
fi
pass "暂存 JWT 被阻断且输出保持脱敏"

special_repo=$TEST_ROOT/special-path-repo
init_repo "$special_repo"
printf '%s\n' 'baseline' >"$special_repo/base.txt"
commit_all "$special_repo" 'test: 建立特殊路径基线'
blob_id=$(git -C "$special_repo" hash-object -w base.txt) || fail "无法创建测试对象。"
special_path='line
break/.env'
git -C "$special_repo" update-index --add --cacheinfo "100644,$blob_id,$special_path" ||
    fail "无法写入特殊路径测试索引。"
special_output=$TEST_ROOT/special.out
expect_exit 1 "$special_output" run_in_repo "$special_repo" \
    "$REPO_DIR/scripts/git_commit_check.sh"
grep -F '暂存路径包含换行、Tab、引号或其他需 Git 转义的字符' "$special_output" \
    >/dev/null 2>&1 || fail "特殊路径未被 fail-closed 阻断。"
pass "换行路径无法绕过敏感文件与体积门禁"

release_repo=$TEST_ROOT/release-repo
init_repo "$release_repo"
printf '%s\n' '{' '  "name": "release-fixture",' '  "version": "1.0.0",' \
    '  "private": true' '}' >"$release_repo/package.json"
printf '%s\n' '{' '  "name": "release-fixture",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3' '}' >"$release_repo/package-lock.json"
printf '%s\n' '1.0.0' >"$release_repo/VERSION"
commit_all "$release_repo" 'test: 建立发布候选'
git -C "$release_repo" tag v1.0.0 || fail "无法创建测试 Tag。"
release_output=$TEST_ROOT/release.out
expect_exit 1 "$release_output" run_in_repo "$release_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -F '是否允许发布：有条件允许' "$release_output" >/dev/null 2>&1 ||
    fail "未知远端状态未形成有条件结论。"
pass "发布未知项使用非零退出码防止自动化误放行"

git -C "$release_repo" remote add origin "$TEST_ROOT/release-origin.git" ||
    fail "无法配置发布测试远端。"
git -C "$release_repo" update-ref refs/remotes/origin/main HEAD ||
    fail "无法建立发布测试远端跟踪引用。"
git -C "$release_repo" branch --set-upstream-to=origin/main main >/dev/null 2>&1 ||
    fail "无法配置发布测试上游。"
sync_output=$TEST_ROOT/sync.out
expect_exit 0 "$sync_output" run_in_repo "$release_repo" \
    "$REPO_DIR/scripts/branch_sync.sh" --branch main --remote origin
grep -F '同步结论：基于本地引用已同步' "$sync_output" >/dev/null 2>&1 ||
    fail "已同步分支未返回成功结论。"
pass "已同步分支可以通过同步检查"

release_ready_output=$TEST_ROOT/release-ready.out
expect_exit 0 "$release_ready_output" run_in_repo "$release_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -F '是否允许发布：是' "$release_ready_output" >/dev/null 2>&1 ||
    fail "完整发布证据未返回允许发布结论。"
grep -F 'VERSION' "$release_ready_output" >/dev/null 2>&1 ||
    fail "通用 VERSION 文件未进入版本证据。"
grep -F '首次发布完整树' "$release_ready_output" >/dev/null 2>&1 ||
    fail "首次发布未检查 HEAD 完整树。"
grep -E '发布变更文件.*3$' "$release_ready_output" >/dev/null 2>&1 ||
    fail "首次发布没有把全部三个跟踪文件纳入差异门禁。"
pass "版本、Tag 与上游一致时发布检查可以通过"

printf '%s\n' '{' '  "name": "release-fixture",' '  "version": "1.1.0",' \
    '  "private": true' '}' >"$release_repo/package.json"
printf '%s\n' '{' '  "name": "release-fixture",' '  "version": "1.1.0",' \
    '  "lockfileVersion": 3' '}' >"$release_repo/package-lock.json"
printf '%s\n' '1.1.0' >"$release_repo/VERSION"
commit_all "$release_repo" 'test: 建立递增发布候选'
git -C "$release_repo" tag v1.1.0 || fail "无法创建递增版本测试 Tag。"
git -C "$release_repo" update-ref refs/remotes/origin/main HEAD ||
    fail "无法更新递增版本测试远端跟踪引用。"
upgrade_output=$TEST_ROOT/upgrade.out
expect_exit 0 "$upgrade_output" run_in_repo "$release_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -F '候选版本 1.1.0 高于上一发布版本 1.0.0' "$upgrade_output" >/dev/null 2>&1 ||
    fail "语义版本递增未形成通过证据。"
grep -F '是否允许发布：是' "$upgrade_output" >/dev/null 2>&1 ||
    fail "语义版本递增未返回允许发布结论。"
pass "候选版本高于历史版本时发布检查可以通过"

same_base_output=$TEST_ROOT/base-head.out
expect_exit 5 "$same_base_output" run_in_repo "$release_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base HEAD
grep -F '发布比较基线必须是 HEAD 的严格祖先' "$same_base_output" >/dev/null 2>&1 ||
    fail "--base HEAD 未返回严格祖先约束。"
grep -F '不能与 HEAD 相同' "$same_base_output" >/dev/null 2>&1 ||
    fail "--base HEAD 未明确指出基线与 HEAD 相同。"
pass "--base HEAD 以引用关系退出码拒绝"

downgrade_repo=$TEST_ROOT/downgrade-repo
init_repo "$downgrade_repo"
printf '%s\n' '2.0.0' >"$downgrade_repo/VERSION"
commit_all "$downgrade_repo" 'test: 建立较高版本基线'
git -C "$downgrade_repo" tag v2.0.0 || fail "无法创建较高版本测试 Tag。"
printf '%s\n' '1.0.0' >"$downgrade_repo/VERSION"
commit_all "$downgrade_repo" 'test: 建立版本降级候选'
git -C "$downgrade_repo" tag v1.0.0 || fail "无法创建降级候选测试 Tag。"
git -C "$downgrade_repo" remote add origin "$TEST_ROOT/downgrade-origin.git" ||
    fail "无法配置版本降级测试远端。"
git -C "$downgrade_repo" update-ref refs/remotes/origin/main HEAD ||
    fail "无法建立版本降级测试远端跟踪引用。"
git -C "$downgrade_repo" branch --set-upstream-to=origin/main main >/dev/null 2>&1 ||
    fail "无法配置版本降级测试上游。"
downgrade_output=$TEST_ROOT/downgrade.out
expect_exit 1 "$downgrade_output" run_in_repo "$downgrade_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -F '未高于上一发布版本 2.0.0' "$downgrade_output" >/dev/null 2>&1 ||
    fail "版本降级未被发布检查阻断。"
grep -F '是否允许发布：否' "$downgrade_output" >/dev/null 2>&1 ||
    fail "版本降级未形成拒绝发布结论。"
pass "候选版本低于历史版本时发布检查 fail-closed"

untracked_config_repo=$TEST_ROOT/untracked-config-repo
init_repo "$untracked_config_repo"
printf '%s\n' '1.0.0' >"$untracked_config_repo/VERSION"
commit_all "$untracked_config_repo" 'test: 建立未跟踪配置隐藏基线'
git -C "$untracked_config_repo" tag v1.0.0 ||
    fail "无法创建未跟踪配置隐藏 Tag。"
configure_local_upstream "$untracked_config_repo" untracked-config
git -C "$untracked_config_repo" config status.showUntrackedFiles no ||
    fail "无法配置 status.showUntrackedFiles=no。"
printf '%s\n' 'untracked release input' >"$untracked_config_repo/hidden.txt"
[ -z "$(git -C "$untracked_config_repo" status --porcelain)" ] ||
    fail "Git 默认 status 没有隐藏未跟踪夹具。"
untracked_config_output=$TEST_ROOT/untracked-config.out
expect_exit 1 "$untracked_config_output" run_in_repo "$untracked_config_repo" \
    "$REPO_DIR/scripts/release_check.sh"
assert_release_blocked "$untracked_config_output" '工作区不干净' '?? hidden.txt'
pass "status.showUntrackedFiles=no 无法隐藏未跟踪发布输入"

symlink_version_repo=$TEST_ROOT/symlink-version-repo
init_repo "$symlink_version_repo"
printf '%s\n' '1.0.0' >"$symlink_version_repo/real-version.txt"
ln -s real-version.txt "$symlink_version_repo/VERSION" ||
    fail "无法创建 VERSION 符号链接夹具。"
commit_all "$symlink_version_repo" 'test: 建立符号链接版本源'
git -C "$symlink_version_repo" tag v1.0.0 || fail "无法创建符号链接版本 Tag。"
configure_local_upstream "$symlink_version_repo" symlink-version
symlink_version_output=$TEST_ROOT/symlink-version.out
expect_exit 1 "$symlink_version_output" run_in_repo "$symlink_version_repo" \
    "$REPO_DIR/scripts/release_check.sh"
assert_release_blocked "$symlink_version_output" \
    '版本来源不是 HEAD 中的普通文件' '符号链接' 'VERSION'
pass "受跟踪 VERSION 符号链接不能作为发布版本源"

gitlink_repo=$TEST_ROOT/gitlink-repo
init_repo "$gitlink_repo"
printf '%s\n' '1.0.0' >"$gitlink_repo/VERSION"
commit_all "$gitlink_repo" 'test: 建立 gitlink 发布基线'
mkdir -p "$gitlink_repo/vendor/sub" || fail "无法创建 gitlink 嵌套仓库目录。"
git -C "$gitlink_repo/vendor/sub" init -b main >/dev/null 2>&1 ||
    fail "无法初始化 gitlink 嵌套仓库。"
printf '%s\n' 'submodule content' >"$gitlink_repo/vendor/sub/content.txt"
commit_all "$gitlink_repo/vendor/sub" 'test: 建立 gitlink 固定提交'
gitlink_commit=$(git -C "$gitlink_repo/vendor/sub" rev-parse HEAD) ||
    fail "无法读取 gitlink 固定提交。"
git -C "$gitlink_repo" update-index --add \
    --cacheinfo "160000,$gitlink_commit,vendor/sub" ||
    fail "无法写入 mode 160000 gitlink。"
git -C "$gitlink_repo" -c user.name='Integration Test' \
    -c user.email='integration@example.invalid' commit -m 'test: 跟踪 gitlink 候选' \
    >/dev/null 2>&1 || fail "无法提交 gitlink 候选。"
[ -z "$(git -C "$gitlink_repo" status --porcelain --untracked-files=all)" ] ||
    fail "真实 gitlink 候选的父仓库工作区不干净。"
gitlink_tree_entry=$(git -C "$gitlink_repo" ls-tree HEAD -- vendor/sub) ||
    fail "无法读取 gitlink tree entry。"
printf '%s\n' "$gitlink_tree_entry" |
    grep -E '^160000 commit [0-9a-f]+[[:space:]]+vendor/sub$' >/dev/null 2>&1 ||
    fail "gitlink 夹具未形成 mode 160000 commit 条目。"
git -C "$gitlink_repo" tag v1.0.0 || fail "无法创建 gitlink 候选 Tag。"
configure_local_upstream "$gitlink_repo" gitlink
gitlink_output=$TEST_ROOT/gitlink.out
expect_exit 1 "$gitlink_output" run_in_repo "$gitlink_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -E '阻断项[^0-9]*0([^0-9]|$)' "$gitlink_output" >/dev/null 2>&1 ||
    fail "gitlink clean 候选被误判为 blocker。"
grep -E '未知项[^0-9]*[1-9][0-9]*' "$gitlink_output" >/dev/null 2>&1 ||
    fail "gitlink clean 候选没有形成未知项。"
grep -F '是否允许发布：有条件允许' "$gitlink_output" >/dev/null 2>&1 ||
    fail "gitlink clean 候选未形成有条件允许结论。"
grep -F 'HEAD 包含 submodule gitlink' "$gitlink_output" >/dev/null 2>&1 ||
    fail "gitlink clean 候选没有输出递归审计限制。"
grep -F 'vendor/sub' "$gitlink_output" >/dev/null 2>&1 ||
    fail "gitlink clean 候选没有输出具体路径。"
pass "真实 mode 160000 gitlink 形成非阻断未知项"

shallow_source_repo=$TEST_ROOT/shallow-source-repo
init_repo "$shallow_source_repo"
printf '%s\n' '1.0.0' >"$shallow_source_repo/VERSION"
commit_all "$shallow_source_repo" 'test: 建立 shallow 历史版本'
git -C "$shallow_source_repo" tag v1.0.0 || fail "无法创建 shallow 历史 Tag。"
printf '%s\n' '1.1.0' >"$shallow_source_repo/VERSION"
commit_all "$shallow_source_repo" 'test: 建立 shallow 候选版本'
git -C "$shallow_source_repo" tag v1.1.0 || fail "无法创建 shallow 候选 Tag。"
shallow_remote_repo=$TEST_ROOT/shallow-origin.git
git clone --bare "$shallow_source_repo" "$shallow_remote_repo" >/dev/null 2>&1 ||
    fail "无法创建 shallow 测试本地裸远端。"
shallow_repo=$TEST_ROOT/shallow-repo
git clone --depth 1 --branch main "file://$shallow_remote_repo" "$shallow_repo" \
    >/dev/null 2>&1 || fail "无法创建 depth 1 shallow clone。"
[ "$(git -C "$shallow_repo" rev-parse --is-shallow-repository)" = 'true' ] ||
    fail "depth 1 夹具未形成 shallow repository。"
git -C "$shallow_source_repo" rev-parse --verify 'v1.0.0^{commit}' >/dev/null 2>&1 ||
    fail "shallow 源仓库缺少上一发布 Tag。"
if git -C "$shallow_repo" rev-parse --verify 'v1.0.0^{commit}' >/dev/null 2>&1; then
    fail "depth 1 clone 意外包含上一发布 Tag 历史。"
fi
[ -z "$(git -C "$shallow_repo" status --porcelain --untracked-files=all)" ] ||
    fail "shallow clone 候选工作区不干净。"
shallow_output=$TEST_ROOT/shallow.out
expect_exit 1 "$shallow_output" run_in_repo "$shallow_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -E '阻断项[^0-9]*0([^0-9]|$)' "$shallow_output" >/dev/null 2>&1 ||
    fail "shallow clone 被无关 blocker 干扰。"
grep -E '未知项[^0-9]*[1-9][0-9]*' "$shallow_output" >/dev/null 2>&1 ||
    fail "shallow clone 没有形成未知项。"
grep -F '当前是 shallow clone' "$shallow_output" >/dev/null 2>&1 ||
    fail "shallow clone 没有输出历史边界诊断。"
grep -F '是否允许发布：有条件允许' "$shallow_output" >/dev/null 2>&1 ||
    fail "shallow clone 未形成有条件允许结论。"
if grep -F '是否允许发布：是' "$shallow_output" >/dev/null 2>&1; then
    fail "shallow clone 被错误放行为允许发布。"
fi
pass "缺失上一 Tag 历史的 shallow clone 不会被直接放行"

skip_repo=$TEST_ROOT/skip-worktree-repo
init_repo "$skip_repo"
mkdir -p "$skip_repo/src" || fail "无法创建 skip-worktree 测试目录。"
printf '%s\n' '1.0.0' >"$skip_repo/VERSION"
printf '%s\n' 'export function run() {' '    return true;' '}' >"$skip_repo/src/app.js"
commit_all "$skip_repo" 'test: 建立索引隐藏基线'
git -C "$skip_repo" tag v1.0.0 || fail "无法创建索引隐藏基线 Tag。"
printf '%s\n' '1.0.1' >"$skip_repo/VERSION"
printf '%s\n' 'export function run() {' '    console.log("candidate");' \
    '    return true;' '}' >"$skip_repo/src/app.js"
commit_all "$skip_repo" 'test: 建立包含调试代码的候选提交'
git -C "$skip_repo" tag v1.0.1 || fail "无法创建索引隐藏候选 Tag。"
configure_local_upstream "$skip_repo" skip-worktree
git -C "$skip_repo" update-index --skip-worktree src/app.js ||
    fail "无法标记 skip-worktree 测试文件。"
printf '%s\n' 'export function run() {' '    return true;' '}' >"$skip_repo/src/app.js"
[ -z "$(git -C "$skip_repo" status --porcelain)" ] ||
    fail "skip-worktree 夹具未隐藏工作树改动。"
skip_index_entry=$(git -C "$skip_repo" ls-files -v -- src/app.js) ||
    fail "无法读取 skip-worktree 索引标记。"
case $skip_index_entry in
    'S src/app.js') ;;
    *) fail "skip-worktree 夹具未形成 S 索引标记。" ;;
esac
git -C "$skip_repo" show HEAD:src/app.js >"$TEST_ROOT/skip-head.js" ||
    fail "无法读取候选提交中的调试代码。"
grep -F 'console.log' "$TEST_ROOT/skip-head.js" >/dev/null 2>&1 ||
    fail "候选提交没有保留预期调试代码。"
skip_head_blob=$(git -C "$skip_repo" rev-parse HEAD:src/app.js) ||
    fail "无法计算候选提交 Blob。"
skip_worktree_blob=$(git -C "$skip_repo" hash-object src/app.js) ||
    fail "无法计算工作树 Blob。"
[ "$skip_head_blob" != "$skip_worktree_blob" ] ||
    fail "skip-worktree 夹具中的 HEAD 与工作树内容没有差异。"
skip_output=$TEST_ROOT/skip-worktree.out
expect_exit 1 "$skip_output" run_in_repo "$skip_repo" \
    "$REPO_DIR/scripts/release_check.sh"
assert_release_blocked "$skip_output" 'skip-worktree' 'src/app.js'
grep -F 'HEAD:src/app.js:' "$skip_output" >/dev/null 2>&1 ||
    fail "发布检查没有以 HEAD:src/app.js 定位候选提交内容。"
pass "skip-worktree 无法隐藏候选提交中的调试代码"

nested_version_repo=$TEST_ROOT/nested-version-repo
init_repo "$nested_version_repo"
printf '%s\n' '{' '  "name": "version-fixture",' '  "version": "1.2.2"' '}' \
    >"$nested_version_repo/package.json"
printf '%s\n' '{' '  "name": "version-fixture",' '  "version": "1.2.2",' \
    '  "lockfileVersion": 3' '}' >"$nested_version_repo/package-lock.json"
commit_all "$nested_version_repo" 'test: 建立顶层版本解析基线'
git -C "$nested_version_repo" tag v1.2.2 || fail "无法创建顶层版本解析基线 Tag。"
printf '%s\n' '{' '  "metadata": {' '    "version": "99.0.0"' '  },' \
    '  "name": "version-fixture",' '  "version": "1.2.3"' '}' \
    >"$nested_version_repo/package.json"
printf '%s\n' '{' '  "name": "version-fixture",' '  "version": "1.2.3",' \
    '  "lockfileVersion": 3' '}' >"$nested_version_repo/package-lock.json"
commit_all "$nested_version_repo" 'test: 更新顶层版本并保留嵌套陷阱'
git -C "$nested_version_repo" tag v1.2.3 || fail "无法创建顶层版本解析候选 Tag。"
configure_local_upstream "$nested_version_repo" nested-version
nested_version_output=$TEST_ROOT/nested-version.out
expect_exit 0 "$nested_version_output" run_in_repo "$nested_version_repo" \
    "$REPO_DIR/scripts/release_check.sh"
assert_release_allowed "$nested_version_output"
grep -E 'package\.json[[:space:]]+1\.2\.3' "$nested_version_output" >/dev/null 2>&1 ||
    fail "package.json 顶层版本未被识别为 1.2.3。"
grep -E '唯一版本值[^0-9]*1([^0-9]|$)' "$nested_version_output" >/dev/null 2>&1 ||
    fail "嵌套 version 干扰了唯一版本统计。"
if grep -F '99.0.0' "$nested_version_output" >/dev/null 2>&1; then
    fail "嵌套 metadata.version 被误认为发布版本。"
fi
pass "package.json 只读取顶层 version"

node_lock_symlink_repo=$TEST_ROOT/node-lock-symlink-repo
init_repo "$node_lock_symlink_repo"
printf '%s\n' '{' '  "name": "lock-symlink-fixture",' '  "version": "1.0.0"' '}' \
    >"$node_lock_symlink_repo/package.json"
printf '%s\n' '{' '  "name": "lock-symlink-fixture",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3' '}' >"$node_lock_symlink_repo/lock-data.json"
ln -s lock-data.json "$node_lock_symlink_repo/package-lock.json" ||
    fail "无法创建 Node lock 符号链接夹具。"
commit_all "$node_lock_symlink_repo" 'test: 建立 Node lock 符号链接候选'
git -C "$node_lock_symlink_repo" tag v1.0.0 ||
    fail "无法创建 Node lock 符号链接候选 Tag。"
configure_local_upstream "$node_lock_symlink_repo" node-lock-symlink
node_lock_symlink_output=$TEST_ROOT/node-lock-symlink.out
expect_exit 1 "$node_lock_symlink_output" run_in_repo "$node_lock_symlink_repo" \
    "$REPO_DIR/scripts/release_check.sh"
assert_release_blocked "$node_lock_symlink_output" \
    '依赖 manifest/lock 不是 HEAD 中的普通文件' 'package-lock.json'
pass "受跟踪 Node lock 符号链接不能作为依赖锁文件"

spm_manifest_repo=$TEST_ROOT/spm-manifest-only-repo
init_repo "$spm_manifest_repo"
printf '%s\n' '1.0.0' >"$spm_manifest_repo/VERSION"
printf '%s\n' '// swift-tools-version: 5.9' 'import PackageDescription' \
    'let package = Package(name: "Fixture")' >"$spm_manifest_repo/Package.swift"
printf '%s\n' '{"version":2,"pins":[]}' >"$spm_manifest_repo/Package.resolved"
commit_all "$spm_manifest_repo" 'test: 建立 SwiftPM 配对基线'
git -C "$spm_manifest_repo" tag v1.0.0 || fail "无法创建 SwiftPM manifest 基线 Tag。"
printf '%s\n' '1.0.1' >"$spm_manifest_repo/VERSION"
printf '%s\n' '// swift-tools-version: 5.9' 'import PackageDescription' \
    'let package = Package(name: "Fixture", products: [])' >"$spm_manifest_repo/Package.swift"
commit_all "$spm_manifest_repo" 'test: 只修改 SwiftPM manifest'
git -C "$spm_manifest_repo" tag v1.0.1 || fail "无法创建 SwiftPM manifest 候选 Tag。"
configure_local_upstream "$spm_manifest_repo" spm-manifest-only
spm_manifest_output=$TEST_ROOT/spm-manifest-only.out
expect_exit 1 "$spm_manifest_output" run_in_repo "$spm_manifest_repo" \
    "$REPO_DIR/scripts/release_check.sh"
assert_release_blocked "$spm_manifest_output" 'Package.swift' 'Package.resolved'
pass "Package.swift 单独变化会阻断发布"

spm_resolved_repo=$TEST_ROOT/spm-resolved-only-repo
init_repo "$spm_resolved_repo"
printf '%s\n' '1.0.0' >"$spm_resolved_repo/VERSION"
printf '%s\n' '// swift-tools-version: 5.9' 'import PackageDescription' \
    'let package = Package(name: "Fixture")' >"$spm_resolved_repo/Package.swift"
printf '%s\n' '{"version":2,"pins":[]}' >"$spm_resolved_repo/Package.resolved"
commit_all "$spm_resolved_repo" 'test: 建立 SwiftPM 解析文件基线'
git -C "$spm_resolved_repo" tag v1.0.0 || fail "无法创建 SwiftPM resolved 基线 Tag。"
printf '%s\n' '1.0.1' >"$spm_resolved_repo/VERSION"
printf '%s\n' '{"version":3,"pins":[]}' >"$spm_resolved_repo/Package.resolved"
commit_all "$spm_resolved_repo" 'test: 只修改 SwiftPM resolved'
git -C "$spm_resolved_repo" tag v1.0.1 || fail "无法创建 SwiftPM resolved 候选 Tag。"
configure_local_upstream "$spm_resolved_repo" spm-resolved-only
spm_resolved_output=$TEST_ROOT/spm-resolved-only.out
expect_exit 0 "$spm_resolved_output" run_in_repo "$spm_resolved_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -E '阻断项[^0-9]*0([^0-9]|$)' "$spm_resolved_output" >/dev/null 2>&1 ||
    fail "Package.resolved 单独变化产生了阻断项。"
grep -F '是否允许发布：有条件允许' "$spm_resolved_output" >/dev/null 2>&1 ||
    fail "Package.resolved 单独变化未形成有条件允许结论。"
grep -F '[警告] Package.resolved 单独变更或由 Xcode workspace 管理' \
    "$spm_resolved_output" >/dev/null 2>&1 ||
    fail "Package.resolved 单独变化未产生精确的依赖解析警告。"
pass "Package.resolved 单独变化会明确警告但不阻断发布"

spm_paired_repo=$TEST_ROOT/spm-paired-repo
init_repo "$spm_paired_repo"
printf '%s\n' '1.0.0' >"$spm_paired_repo/VERSION"
printf '%s\n' '// swift-tools-version: 5.9' 'import PackageDescription' \
    'let package = Package(name: "Fixture")' >"$spm_paired_repo/Package.swift"
printf '%s\n' '{"version":2,"pins":[]}' >"$spm_paired_repo/Package.resolved"
commit_all "$spm_paired_repo" 'test: 建立 SwiftPM 成对变化基线'
git -C "$spm_paired_repo" tag v1.0.0 || fail "无法创建 SwiftPM 成对基线 Tag。"
printf '%s\n' '1.0.1' >"$spm_paired_repo/VERSION"
printf '%s\n' '// swift-tools-version: 5.9' 'import PackageDescription' \
    'let package = Package(name: "Fixture", products: [])' >"$spm_paired_repo/Package.swift"
printf '%s\n' '{"version":3,"pins":[]}' >"$spm_paired_repo/Package.resolved"
commit_all "$spm_paired_repo" 'test: 成对修改 SwiftPM 文件'
git -C "$spm_paired_repo" tag v1.0.1 || fail "无法创建 SwiftPM 成对候选 Tag。"
configure_local_upstream "$spm_paired_repo" spm-paired
spm_paired_output=$TEST_ROOT/spm-paired.out
expect_exit 0 "$spm_paired_output" run_in_repo "$spm_paired_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -E '阻断项[^0-9]*0([^0-9]|$)' "$spm_paired_output" >/dev/null 2>&1 ||
    fail "SwiftPM 成对变化仍产生了配对阻断。"
grep -F '[警告] SwiftPM 文件位于发布差异中' "$spm_paired_output" >/dev/null 2>&1 ||
    fail "SwiftPM 成对变化缺少依赖审计警告。"
pass "Package.swift 与 Package.resolved 成对变化可以通过"

spm_lock_delete_repo=$TEST_ROOT/spm-lock-delete-repo
init_repo "$spm_lock_delete_repo"
printf '%s\n' '1.0.0' >"$spm_lock_delete_repo/VERSION"
printf '%s\n' '// swift-tools-version: 5.9' 'import PackageDescription' \
    'let package = Package(name: "Fixture")' >"$spm_lock_delete_repo/Package.swift"
printf '%s\n' '{"version":2,"pins":[]}' >"$spm_lock_delete_repo/Package.resolved"
commit_all "$spm_lock_delete_repo" 'test: 建立 SwiftPM lock 删除基线'
spm_lock_delete_base=$(git -C "$spm_lock_delete_repo" rev-parse HEAD) ||
    fail "无法记录 SwiftPM lock 删除比较基线。"
git -C "$spm_lock_delete_repo" rm -- Package.resolved >/dev/null 2>&1 ||
    fail "无法删除 SwiftPM lock 测试文件。"
commit_all "$spm_lock_delete_repo" 'test: 删除 Package.resolved 但保留 manifest'
git -C "$spm_lock_delete_repo" tag v1.0.0 ||
    fail "无法创建 SwiftPM lock 删除候选 Tag。"
configure_local_upstream "$spm_lock_delete_repo" spm-lock-delete
spm_lock_delete_output=$TEST_ROOT/spm-lock-delete.out
expect_exit 1 "$spm_lock_delete_output" run_in_repo "$spm_lock_delete_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$spm_lock_delete_base"
assert_release_blocked "$spm_lock_delete_output" 'Package.resolved 已删除' \
    'HEAD 仍跟踪同目录 Package.swift'
pass "Package.resolved 删除但 Package.swift 保留时阻断发布"

node_cross_repo=$TEST_ROOT/node-cross-directory-repo
init_repo "$node_cross_repo"
mkdir -p "$node_cross_repo/apps/a" "$node_cross_repo/apps/b" ||
    fail "无法创建 Node 多目录测试夹具。"
for node_package_dir in a b; do
    printf '%s\n' '{' "  \"name\": \"fixture-${node_package_dir}\"," \
        '  "version": "1.0.0"' '}' >"$node_cross_repo/apps/$node_package_dir/package.json"
    printf '%s\n' '{' "  \"name\": \"fixture-${node_package_dir}\"," \
        '  "version": "1.0.0",' '  "lockfileVersion": 3' '}' \
        >"$node_cross_repo/apps/$node_package_dir/package-lock.json"
done
commit_all "$node_cross_repo" 'test: 建立 Node 多目录配对基线'
node_cross_base=$(git -C "$node_cross_repo" rev-parse HEAD) ||
    fail "无法记录 Node 多目录比较基线。"
printf '%s\n' '{' '  "name": "fixture-a",' '  "version": "1.0.0",' \
    '  "dependencies": {' '    "left-pad": "1.3.0"' '  }' '}' \
    >"$node_cross_repo/apps/a/package.json"
printf '%s\n' '{' '  "name": "fixture-b",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3,' '  "packages": {}' '}' \
    >"$node_cross_repo/apps/b/package-lock.json"
commit_all "$node_cross_repo" 'test: 在不同目录交叉修改 Node 文件'
git -C "$node_cross_repo" tag v1.0.0 || fail "无法创建 Node 多目录候选 Tag。"
configure_local_upstream "$node_cross_repo" node-cross-directory
node_cross_output=$TEST_ROOT/node-cross-directory.out
expect_exit 1 "$node_cross_output" run_in_repo "$node_cross_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$node_cross_base"
assert_release_blocked "$node_cross_output" 'apps/a/package.json' \
    'apps/a/package-lock.json'
pass "Node manifest 与其他目录锁文件不能交叉抵消"

node_paired_repo=$TEST_ROOT/node-paired-repo
init_repo "$node_paired_repo"
mkdir -p "$node_paired_repo/apps/a" || fail "无法创建 Node 正向控制目录。"
printf '%s\n' '{' '  "name": "workspace-root",' '  "version": "1.0.0",' \
    '  "private": true,' '  "workspaces": [' '    "apps/*"' '  ]' '}' \
    >"$node_paired_repo/package.json"
printf '%s\n' '{' '  "name": "workspace-root",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3' '}' >"$node_paired_repo/package-lock.json"
printf '%s\n' '{' '  "name": "fixture-a",' '  "version": "1.0.0"' '}' \
    >"$node_paired_repo/apps/a/package.json"
commit_all "$node_paired_repo" 'test: 建立 Node workspace 最近祖先基线'
node_paired_base=$(git -C "$node_paired_repo" rev-parse HEAD) ||
    fail "无法记录 Node workspace 比较基线。"
printf '%s\n' '{' '  "name": "fixture-a",' '  "version": "1.0.0",' \
    '  "dependencies": {' '    "left-pad": "1.3.0"' '  }' '}' \
    >"$node_paired_repo/apps/a/package.json"
printf '%s\n' '{' '  "name": "workspace-root",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3,' '  "packages": {' \
    '    "apps/a": {"version": "1.0.0"}' '  }' '}' \
    >"$node_paired_repo/package-lock.json"
commit_all "$node_paired_repo" 'test: 修改 workspace manifest 与根 lock'
git -C "$node_paired_repo" tag v1.0.0 || fail "无法创建 Node workspace 候选 Tag。"
configure_local_upstream "$node_paired_repo" node-paired
node_paired_output=$TEST_ROOT/node-paired.out
expect_exit 0 "$node_paired_output" run_in_repo "$node_paired_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$node_paired_base"
assert_release_allowed "$node_paired_output"
pass "Node workspace manifest 可以匹配最近祖先根锁文件"

node_undeclared_repo=$TEST_ROOT/node-undeclared-workspace-repo
init_repo "$node_undeclared_repo"
mkdir -p "$node_undeclared_repo/apps/a" || fail "无法创建未声明 workspace 目录。"
printf '%s\n' '{' '  "name": "workspace-root",' '  "version": "1.0.0",' \
    '  "private": true,' '  "workspaces": [' '    "packages/*"' '  ]' '}' \
    >"$node_undeclared_repo/package.json"
printf '%s\n' '{' '  "name": "workspace-root",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3' '}' >"$node_undeclared_repo/package-lock.json"
printf '%s\n' '{' '  "name": "undeclared-a",' '  "version": "1.0.0"' '}' \
    >"$node_undeclared_repo/apps/a/package.json"
commit_all "$node_undeclared_repo" 'test: 建立未声明 workspace 基线'
node_undeclared_base=$(git -C "$node_undeclared_repo" rev-parse HEAD) ||
    fail "无法记录未声明 workspace 比较基线。"
printf '%s\n' '{' '  "name": "undeclared-a",' '  "version": "1.0.0",' \
    '  "dependencies": {' '    "left-pad": "1.3.0"' '  }' '}' \
    >"$node_undeclared_repo/apps/a/package.json"
printf '%s\n' '{' '  "name": "workspace-root",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3,' '  "packages": {' \
    '    "apps/a": {"version": "1.0.0"}' '  }' '}' \
    >"$node_undeclared_repo/package-lock.json"
commit_all "$node_undeclared_repo" 'test: 修改未声明 package 与根 lock'
git -C "$node_undeclared_repo" tag v1.0.0 ||
    fail "无法创建未声明 workspace 候选 Tag。"
configure_local_upstream "$node_undeclared_repo" node-undeclared-workspace
node_undeclared_output=$TEST_ROOT/node-undeclared-workspace.out
expect_exit 1 "$node_undeclared_output" run_in_repo "$node_undeclared_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$node_undeclared_base"
assert_release_blocked "$node_undeclared_output" 'apps/a/package.json' \
    '没有受支持的 Node 锁文件' 'package-lock.json'
pass "未被 workspaces 声明的 package 不能借用根锁文件"

node_metadata_repo=$TEST_ROOT/node-metadata-only-repo
init_repo "$node_metadata_repo"
printf '%s\n' '{' '  "name": "metadata-fixture",' '  "version": "1.0.0",' \
    '  "description": "before"' '}' >"$node_metadata_repo/package.json"
printf '%s\n' '{' '  "name": "metadata-fixture",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3' '}' >"$node_metadata_repo/package-lock.json"
commit_all "$node_metadata_repo" 'test: 建立 Node 非依赖字段基线'
node_metadata_base=$(git -C "$node_metadata_repo" rev-parse HEAD) ||
    fail "无法记录 Node 非依赖字段比较基线。"
printf '%s\n' '{' '  "name": "metadata-fixture",' '  "version": "1.0.0",' \
    '  "description": "after"' '}' >"$node_metadata_repo/package.json"
commit_all "$node_metadata_repo" 'test: 只修改 Node 非依赖字段'
git -C "$node_metadata_repo" tag v1.0.0 ||
    fail "无法创建 Node 非依赖字段候选 Tag。"
configure_local_upstream "$node_metadata_repo" node-metadata-only
node_metadata_output=$TEST_ROOT/node-metadata-only.out
expect_exit 0 "$node_metadata_output" run_in_repo "$node_metadata_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$node_metadata_base"
assert_release_allowed "$node_metadata_output"
grep -F 'package.json 只修改了非依赖字段' "$node_metadata_output" >/dev/null 2>&1 ||
    fail "Node 非依赖字段变化没有形成 lock 无需更新证据。"
pass "Node 非依赖字段单独变化不要求制造 lock 差异"

node_version_only_repo=$TEST_ROOT/node-version-only-repo
init_repo "$node_version_only_repo"
printf '%s\n' '{' '  "name": "version-only-fixture",' '  "version": "1.0.0"' '}' \
    >"$node_version_only_repo/package.json"
printf '%s\n' '{' '  "name": "version-only-fixture",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3' '}' >"$node_version_only_repo/package-lock.json"
commit_all "$node_version_only_repo" 'test: 建立 Node version-only 基线'
node_version_only_base=$(git -C "$node_version_only_repo" rev-parse HEAD) ||
    fail "无法记录 Node version-only 比较基线。"
printf '%s\n' '{' '  "name": "version-only-fixture",' '  "version": "1.0.1"' '}' \
    >"$node_version_only_repo/package.json"
commit_all "$node_version_only_repo" 'test: 只修改 Node version'
git -C "$node_version_only_repo" tag v1.0.1 ||
    fail "无法创建 Node version-only 候选 Tag。"
configure_local_upstream "$node_version_only_repo" node-version-only
node_version_only_output=$TEST_ROOT/node-version-only.out
expect_exit 1 "$node_version_only_output" run_in_repo "$node_version_only_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$node_version_only_base"
assert_release_blocked "$node_version_only_output" 'package.json' 'package-lock.json' \
    '依赖相关字段已变更'
pass "Node version 变化但 lock 未变时阻断发布"

node_lock_delete_repo=$TEST_ROOT/node-lock-delete-repo
init_repo "$node_lock_delete_repo"
printf '%s\n' '{' '  "name": "lock-delete-fixture",' '  "version": "1.0.0"' '}' \
    >"$node_lock_delete_repo/package.json"
printf '%s\n' '{' '  "name": "lock-delete-fixture",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3' '}' >"$node_lock_delete_repo/package-lock.json"
commit_all "$node_lock_delete_repo" 'test: 建立 Node lock 删除基线'
node_lock_delete_base=$(git -C "$node_lock_delete_repo" rev-parse HEAD) ||
    fail "无法记录 Node lock 删除比较基线。"
git -C "$node_lock_delete_repo" rm -- package-lock.json >/dev/null 2>&1 ||
    fail "无法删除 Node lock 测试文件。"
commit_all "$node_lock_delete_repo" 'test: 删除 lock 但保留 manifest'
git -C "$node_lock_delete_repo" tag v1.0.0 || fail "无法创建 Node lock 删除候选 Tag。"
configure_local_upstream "$node_lock_delete_repo" node-lock-delete
node_lock_delete_output=$TEST_ROOT/node-lock-delete.out
expect_exit 1 "$node_lock_delete_output" run_in_repo "$node_lock_delete_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$node_lock_delete_base"
assert_release_blocked "$node_lock_delete_output" 'package-lock.json 已删除' \
    'package.json'
pass "Node lock 删除但 manifest 保留时阻断发布"

node_pair_delete_repo=$TEST_ROOT/node-pair-delete-repo
init_repo "$node_pair_delete_repo"
mkdir -p "$node_pair_delete_repo/packages/legacy" ||
    fail "无法创建 Node 成对删除目录。"
printf '%s\n' '1.0.0' >"$node_pair_delete_repo/VERSION"
printf '%s\n' '{' '  "name": "legacy-fixture",' '  "version": "1.0.0"' '}' \
    >"$node_pair_delete_repo/packages/legacy/package.json"
printf '%s\n' '{' '  "name": "legacy-fixture",' '  "version": "1.0.0",' \
    '  "lockfileVersion": 3' '}' \
    >"$node_pair_delete_repo/packages/legacy/package-lock.json"
commit_all "$node_pair_delete_repo" 'test: 建立 Node 成对删除基线'
node_pair_delete_base=$(git -C "$node_pair_delete_repo" rev-parse HEAD) ||
    fail "无法记录 Node 成对删除比较基线。"
git -C "$node_pair_delete_repo" rm -- packages/legacy/package.json \
    packages/legacy/package-lock.json >/dev/null 2>&1 ||
    fail "无法成对删除 Node manifest 与 lock。"
commit_all "$node_pair_delete_repo" 'test: 成对删除 Node manifest 与 lock'
git -C "$node_pair_delete_repo" tag v1.0.0 ||
    fail "无法创建 Node 成对删除候选 Tag。"
configure_local_upstream "$node_pair_delete_repo" node-pair-delete
node_pair_delete_output=$TEST_ROOT/node-pair-delete.out
expect_exit 0 "$node_pair_delete_output" run_in_repo "$node_pair_delete_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$node_pair_delete_base"
assert_release_allowed "$node_pair_delete_output"
grep -E '发布变更文件[^0-9]*2([^0-9]|$)' "$node_pair_delete_output" >/dev/null 2>&1 ||
    fail "Node 成对删除没有把两个路径纳入发布差异。"
pass "Node package.json 与同目录 lock 成对删除可以通过"

sparse_repo=$TEST_ROOT/sparse-checkout-repo
init_repo "$sparse_repo"
mkdir -p "$sparse_repo/src" "$sparse_repo/docs" ||
    fail "无法创建 sparse-checkout 测试目录。"
printf '%s\n' '1.0.0' >"$sparse_repo/VERSION"
printf '%s\n' 'export const value = 1;' >"$sparse_repo/src/app.js"
printf '%s\n' 'complete documentation' >"$sparse_repo/docs/hidden.txt"
commit_all "$sparse_repo" 'test: 建立 sparse-checkout 候选'
git -C "$sparse_repo" tag v1.0.0 || fail "无法创建 sparse-checkout 候选 Tag。"
configure_local_upstream "$sparse_repo" sparse-checkout
git -C "$sparse_repo" sparse-checkout init --cone >/dev/null 2>&1 ||
    fail "无法初始化 sparse-checkout 夹具。"
git -C "$sparse_repo" sparse-checkout set src >/dev/null 2>&1 ||
    fail "无法应用 sparse-checkout 夹具。"
sparse_index_entry=$(git -C "$sparse_repo" ls-files -v -- docs/hidden.txt) ||
    fail "无法读取 sparse-checkout S 标记。"
case $sparse_index_entry in
    'S docs/hidden.txt') ;;
    *) fail "sparse-checkout 夹具未形成预期 S 标记。" ;;
esac
sparse_output=$TEST_ROOT/sparse-checkout.out
expect_exit 1 "$sparse_output" run_in_repo "$sparse_repo" \
    "$REPO_DIR/scripts/release_check.sh"
grep -E '阻断项[^0-9]*0([^0-9]|$)' "$sparse_output" >/dev/null 2>&1 ||
    fail "sparse-checkout S 标记被误判为 blocker。"
grep -E '未知项[^0-9]*[1-9][0-9]*' "$sparse_output" >/dev/null 2>&1 ||
    fail "sparse-checkout S 标记没有形成未知项。"
grep -F '是否允许发布：有条件允许' "$sparse_output" >/dev/null 2>&1 ||
    fail "sparse-checkout 未形成非零的有条件允许结论。"
grep -F '当前工作树启用了 sparse-checkout' "$sparse_output" >/dev/null 2>&1 ||
    fail "sparse-checkout 未输出配置归因。"
grep -F 'S docs/hidden.txt' "$sparse_output" >/dev/null 2>&1 ||
    fail "sparse-checkout 未输出具体 S 标记路径。"
pass "sparse-checkout 的 S 标记形成未知项而非阻断项"

assume_repo=$TEST_ROOT/assume-unchanged-repo
init_repo "$assume_repo"
mkdir -p "$assume_repo/src" || fail "无法创建 assume-unchanged 测试目录。"
printf '%s\n' '1.0.0' >"$assume_repo/VERSION"
printf '%s\n' 'export const value = 1;' >"$assume_repo/src/app.js"
commit_all "$assume_repo" 'test: 建立 assume-unchanged 候选'
git -C "$assume_repo" tag v1.0.0 || fail "无法创建 assume-unchanged 候选 Tag。"
configure_local_upstream "$assume_repo" assume-unchanged
git -C "$assume_repo" update-index --assume-unchanged src/app.js ||
    fail "无法标记 assume-unchanged 测试文件。"
printf '%s\n' 'export const value = 2;' >"$assume_repo/src/app.js"
[ -z "$(git -C "$assume_repo" status --porcelain --untracked-files=all)" ] ||
    fail "assume-unchanged 夹具未隐藏工作树改动。"
assume_index_entry=$(git -C "$assume_repo" ls-files -v -- src/app.js) ||
    fail "无法读取 assume-unchanged 索引标记。"
case $assume_index_entry in
    [a-z]' src/app.js') ;;
    *) fail "assume-unchanged 夹具未形成小写索引标记。" ;;
esac
assume_output=$TEST_ROOT/assume-unchanged.out
expect_exit 1 "$assume_output" run_in_repo "$assume_repo" \
    "$REPO_DIR/scripts/release_check.sh"
assert_release_blocked "$assume_output" 'assume-unchanged' 'src/app.js'
pass "assume-unchanged 独立阻断发布"

pods_cross_repo=$TEST_ROOT/pods-cross-directory-repo
init_repo "$pods_cross_repo"
mkdir -p "$pods_cross_repo/ios/a" "$pods_cross_repo/ios/b" ||
    fail "无法创建 CocoaPods 多目录测试夹具。"
printf '%s\n' '1.0.0' >"$pods_cross_repo/VERSION"
for pods_dir in a b; do
    printf '%s\n' "platform :ios, '15.0'" "target 'Fixture${pods_dir}' do" \
        "  pod 'Library${pods_dir}', '1.0.0'" 'end' >"$pods_cross_repo/ios/$pods_dir/Podfile"
    printf '%s\n' 'PODS:' "  - Library${pods_dir} (1.0.0)" \
        'COCOAPODS: 1.15.2' >"$pods_cross_repo/ios/$pods_dir/Podfile.lock"
done
commit_all "$pods_cross_repo" 'test: 建立 CocoaPods 多目录配对基线'
pods_cross_base=$(git -C "$pods_cross_repo" rev-parse HEAD) ||
    fail "无法记录 CocoaPods 多目录比较基线。"
printf '%s\n' "platform :ios, '15.0'" "target 'Fixturea' do" \
    "  pod 'Librarya', '1.1.0'" 'end' >"$pods_cross_repo/ios/a/Podfile"
printf '%s\n' 'PODS:' '  - Libraryb (1.1.0)' 'COCOAPODS: 1.15.2' \
    >"$pods_cross_repo/ios/b/Podfile.lock"
commit_all "$pods_cross_repo" 'test: 在不同目录交叉修改 CocoaPods 文件'
git -C "$pods_cross_repo" tag v1.0.0 || fail "无法创建 CocoaPods 多目录候选 Tag。"
configure_local_upstream "$pods_cross_repo" pods-cross-directory
pods_cross_output=$TEST_ROOT/pods-cross-directory.out
expect_exit 1 "$pods_cross_output" run_in_repo "$pods_cross_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$pods_cross_base"
assert_release_blocked "$pods_cross_output" 'ios/a/Podfile' 'ios/a/Podfile.lock'
pass "Podfile 与其他目录锁文件不能交叉抵消"

pods_paired_repo=$TEST_ROOT/pods-paired-repo
init_repo "$pods_paired_repo"
mkdir -p "$pods_paired_repo/ios/a" || fail "无法创建 CocoaPods 正向控制目录。"
printf '%s\n' '1.0.0' >"$pods_paired_repo/VERSION"
printf '%s\n' "platform :ios, '15.0'" "target 'Fixturea' do" \
    "  pod 'Librarya', '1.0.0'" 'end' >"$pods_paired_repo/ios/a/Podfile"
printf '%s\n' 'PODS:' '  - Librarya (1.0.0)' 'COCOAPODS: 1.15.2' \
    >"$pods_paired_repo/ios/a/Podfile.lock"
commit_all "$pods_paired_repo" 'test: 建立 CocoaPods 同目录配对基线'
pods_paired_base=$(git -C "$pods_paired_repo" rev-parse HEAD) ||
    fail "无法记录 CocoaPods 同目录比较基线。"
printf '%s\n' "platform :ios, '15.0'" "target 'Fixturea' do" \
    "  pod 'Librarya', '1.1.0'" 'end' >"$pods_paired_repo/ios/a/Podfile"
printf '%s\n' 'PODS:' '  - Librarya (1.1.0)' 'COCOAPODS: 1.15.2' \
    >"$pods_paired_repo/ios/a/Podfile.lock"
commit_all "$pods_paired_repo" 'test: 在同目录成对修改 CocoaPods 文件'
git -C "$pods_paired_repo" tag v1.0.0 || fail "无法创建 CocoaPods 同目录候选 Tag。"
configure_local_upstream "$pods_paired_repo" pods-paired
pods_paired_output=$TEST_ROOT/pods-paired.out
expect_exit 0 "$pods_paired_output" run_in_repo "$pods_paired_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$pods_paired_base"
assert_release_allowed "$pods_paired_output"
pass "Podfile 与同目录 Podfile.lock 成对变化可以通过"

pods_lock_delete_repo=$TEST_ROOT/pods-lock-delete-repo
init_repo "$pods_lock_delete_repo"
mkdir -p "$pods_lock_delete_repo/ios/a" ||
    fail "无法创建 CocoaPods lock 删除目录。"
printf '%s\n' '1.0.0' >"$pods_lock_delete_repo/VERSION"
printf '%s\n' "platform :ios, '15.0'" "target 'Fixturea' do" \
    "  pod 'Librarya', '1.0.0'" 'end' >"$pods_lock_delete_repo/ios/a/Podfile"
printf '%s\n' 'PODS:' '  - Librarya (1.0.0)' 'COCOAPODS: 1.15.2' \
    >"$pods_lock_delete_repo/ios/a/Podfile.lock"
commit_all "$pods_lock_delete_repo" 'test: 建立 CocoaPods lock 删除基线'
pods_lock_delete_base=$(git -C "$pods_lock_delete_repo" rev-parse HEAD) ||
    fail "无法记录 CocoaPods lock 删除比较基线。"
git -C "$pods_lock_delete_repo" rm -- ios/a/Podfile.lock >/dev/null 2>&1 ||
    fail "无法删除 CocoaPods lock 测试文件。"
commit_all "$pods_lock_delete_repo" 'test: 删除 Podfile.lock 但保留 Podfile'
git -C "$pods_lock_delete_repo" tag v1.0.0 ||
    fail "无法创建 CocoaPods lock 删除候选 Tag。"
configure_local_upstream "$pods_lock_delete_repo" pods-lock-delete
pods_lock_delete_output=$TEST_ROOT/pods-lock-delete.out
expect_exit 1 "$pods_lock_delete_output" run_in_repo "$pods_lock_delete_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$pods_lock_delete_base"
assert_release_blocked "$pods_lock_delete_output" 'ios/a/Podfile.lock 已删除' \
    'HEAD 仍跟踪同目录 ios/a/Podfile'
pass "Podfile.lock 删除但 Podfile 保留时阻断发布"

pods_lock_rename_repo=$TEST_ROOT/pods-lock-rename-repo
init_repo "$pods_lock_rename_repo"
mkdir -p "$pods_lock_rename_repo/ios/a" ||
    fail "无法创建 CocoaPods lock rename-away 目录。"
printf '%s\n' '1.0.0' >"$pods_lock_rename_repo/VERSION"
printf '%s\n' "platform :ios, '15.0'" "target 'Fixturea' do" \
    "  pod 'Librarya', '1.0.0'" 'end' >"$pods_lock_rename_repo/ios/a/Podfile"
printf '%s\n' 'PODS:' '  - Librarya (1.0.0)' 'COCOAPODS: 1.15.2' \
    >"$pods_lock_rename_repo/ios/a/Podfile.lock"
commit_all "$pods_lock_rename_repo" 'test: 建立 CocoaPods lock rename-away 基线'
pods_lock_rename_base=$(git -C "$pods_lock_rename_repo" rev-parse HEAD) ||
    fail "无法记录 CocoaPods lock rename-away 比较基线。"
git -C "$pods_lock_rename_repo" mv -- ios/a/Podfile.lock ios/a/Podfile.lock.bak ||
    fail "无法重命名 CocoaPods lock 测试文件。"
commit_all "$pods_lock_rename_repo" 'test: 将 Podfile.lock 重命名为备份文件'
git -C "$pods_lock_rename_repo" tag v1.0.0 ||
    fail "无法创建 CocoaPods lock rename-away 候选 Tag。"
configure_local_upstream "$pods_lock_rename_repo" pods-lock-rename
pods_lock_rename_diff=$TEST_ROOT/pods-lock-rename-diff.out
git -C "$pods_lock_rename_repo" diff --name-status --no-renames \
    "$pods_lock_rename_base...HEAD" >"$pods_lock_rename_diff" ||
    fail "无法验证 CocoaPods lock rename-away 差异。"
grep -E '^D[[:space:]]+ios/a/Podfile\.lock$' "$pods_lock_rename_diff" >/dev/null 2>&1 ||
    fail "rename-away 夹具没有形成原 lock 删除记录。"
grep -E '^A[[:space:]]+ios/a/Podfile\.lock\.bak$' "$pods_lock_rename_diff" >/dev/null 2>&1 ||
    fail "rename-away 夹具没有形成备份路径新增记录。"
pods_lock_rename_output=$TEST_ROOT/pods-lock-rename.out
expect_exit 1 "$pods_lock_rename_output" run_in_repo "$pods_lock_rename_repo" \
    "$REPO_DIR/scripts/release_check.sh" --base "$pods_lock_rename_base"
assert_release_blocked "$pods_lock_rename_output" 'ios/a/Podfile.lock 已删除' \
    'HEAD 仍跟踪同目录 ios/a/Podfile'
pass "Podfile.lock rename-away 不能绕过 lock 删除阻断"

merge_repo=$TEST_ROOT/merge-repo
init_repo "$merge_repo"
printf '%s\n' 'baseline' >"$merge_repo/conflict.txt"
commit_all "$merge_repo" 'test: 建立合并基线'
git -C "$merge_repo" switch -c feature/conflict >/dev/null 2>&1 ||
    fail "无法创建测试功能分支。"
printf '%s\n' 'feature value' >"$merge_repo/conflict.txt"
commit_all "$merge_repo" 'test: 修改功能分支值'
git -C "$merge_repo" switch main >/dev/null 2>&1 || fail "无法切回测试主分支。"
printf '%s\n' 'main value' >"$merge_repo/conflict.txt"
commit_all "$merge_repo" 'test: 修改主分支值'
objects_before=$(find "$merge_repo/.git/objects" -type f | awk 'END { print NR + 0 }')
merge_output=$TEST_ROOT/merge.out
expect_exit 1 "$merge_output" run_in_repo "$merge_repo" \
    "$REPO_DIR/scripts/merge_check.sh" main feature/conflict
objects_after=$(find "$merge_repo/.git/objects" -type f | awk 'END { print NR + 0 }')
[ "$objects_before" -eq "$objects_after" ] || fail "merge-tree 向真实对象目录写入了对象。"
grep -F '现代 merge-tree 预测到冲突' "$merge_output" >/dev/null 2>&1 ||
    fail "真实冲突未被 merge-tree 阻断。"
[ -z "$(git -C "$merge_repo" status --porcelain)" ] || fail "合并预演改变了工作区。"
pass "冲突预演使用隔离对象目录且不修改工作区"

clean_merge_repo=$TEST_ROOT/merge:clean-repo
init_repo "$clean_merge_repo"
printf '%s\n' 'baseline' >"$clean_merge_repo/base.txt"
commit_all "$clean_merge_repo" 'test: 建立无冲突合并基线'
git -C "$clean_merge_repo" switch -c feature/clean >/dev/null 2>&1 ||
    fail "无法创建无冲突测试功能分支。"
printf '%s\n' 'feature value' >"$clean_merge_repo/feature.txt"
commit_all "$clean_merge_repo" 'test: 添加功能分支文件'
git -C "$clean_merge_repo" switch main >/dev/null 2>&1 ||
    fail "无法切回无冲突测试主分支。"
printf '%s\n' 'main value' >"$clean_merge_repo/main.txt"
commit_all "$clean_merge_repo" 'test: 添加主分支文件'
clean_objects_before=$(find "$clean_merge_repo/.git/objects" -type f | awk 'END { print NR + 0 }')
clean_merge_output=$TEST_ROOT/merge-clean.out
expect_exit 0 "$clean_merge_output" run_in_repo "$clean_merge_repo" \
    "$REPO_DIR/scripts/merge_check.sh" main feature/clean
clean_objects_after=$(find "$clean_merge_repo/.git/objects" -type f | awk 'END { print NR + 0 }')
[ "$clean_objects_before" -eq "$clean_objects_after" ] ||
    fail "无冲突 merge-tree 向真实对象目录写入了对象。"
grep -F '未预测到冲突' "$clean_merge_output" >/dev/null 2>&1 ||
    fail "无冲突合并未返回可进入人工确认的证据。"
[ -z "$(git -C "$clean_merge_repo" status --porcelain)" ] ||
    fail "无冲突合并预演改变了工作区。"
pass "含冒号仓库路径下的无冲突预演可以通过且不修改工作区"

rollback_output=$TEST_ROOT/rollback.out
expect_exit 6 "$rollback_output" run_in_repo "$merge_repo" \
    "$REPO_DIR/scripts/rollback_check.sh" reset --hard HEAD
grep -F '安全策略禁止 reset --hard' "$rollback_output" >/dev/null 2>&1 ||
    fail "禁止 hard reset 的原因未输出。"
pass "hard reset 始终以安全策略退出码拒绝"

attacker_root=$TEST_ROOT/attacker
mkdir -p "$attacker_root/scripts" "$attacker_root/shared/scripts" ||
    fail "无法创建符号链接攻击夹具。"
printf '%s\n' 'das_print_exit_codes() { printf "%s\n" "HIJACKED_LIBRARY"; }' \
    >"$attacker_root/shared/scripts/lib.sh"
ln -s "$REPO_DIR/scripts/git_summary.sh" "$attacker_root/scripts/git_summary.sh" ||
    fail "无法创建测试符号链接。"
symlink_output=$TEST_ROOT/symlink.out
expect_exit 0 "$symlink_output" "$attacker_root/scripts/git_summary.sh" --help
if grep -F 'HIJACKED_LIBRARY' "$symlink_output" >/dev/null 2>&1; then
    fail "外部符号链接劫持了公共库。"
fi
grep -F '退出码：' "$symlink_output" >/dev/null 2>&1 ||
    fail "符号链接调用未加载真实公共库。"
pass "外部符号链接调用解析到可信公共库"

index_output=$TEST_ROOT/index.out
expect_exit 4 "$index_output" run_in_repo "$release_repo" \
    env GIT_INDEX_FILE="$TEST_ROOT" \
    "$REPO_DIR/scripts/git_changed_files.sh" --all --name-only
grep -F '无法读取已暂存文件清单' "$index_output" >/dev/null 2>&1 ||
    fail "损坏 index 未产生明确错误。"
pass "Git index 读取失败时检查脚本 fail-closed"

[ "$TEST_COUNT" -eq "$EXPECTED_TEST_COUNT" ] ||
    fail "测试计数异常：期望 ${EXPECTED_TEST_COUNT} 项，实际 ${TEST_COUNT} 项。"
printf '%s\n' "集成测试完成：$TEST_COUNT 项通过。"
