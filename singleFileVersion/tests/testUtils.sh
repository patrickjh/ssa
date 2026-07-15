# testUtils.sh — shared helpers for single-file ssa offline tests.
# Sourced by runTests.sh and by each *.test.sh. See
# markdownForAgents/TESTS.md.

[ -n "${TESTS_FOLDER:-}" ] ||
    { printf 'testUtils.sh: TESTS_FOLDER not set\n' >&2; exit 1; }
SINGLE_FILE_FOLDER=$(CDPATH= cd -- "$TESTS_FOLDER/.." && pwd) ||
    { printf 'cannot resolve singleFileVersion folder\n' >&2; exit 1; }
SSA_SCRIPT="$SINGLE_FILE_FOLDER/ssa"
FAKE_CURL="$TESTS_FOLDER/fakeCurl.sh"
STUB_SANDBOX_COMMAND="$TESTS_FOLDER/stubSandboxCommand.sh"

[ -f "$SSA_SCRIPT" ] || { printf 'not found: %s\n' "$SSA_SCRIPT" >&2
    exit 1; }
chmod +x "$FAKE_CURL" "$STUB_SANDBOX_COMMAND" 2>/dev/null

DONE_SENTINEL='echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT'

write_script_reply() {
    printf 'THOUGHT: next step.\n\n```ssa_script\n%s\n```\n' "$2" >"$1"
}

CASE_FOLDER=""
CASE_TMPDIR=""
REPLIES_FOLDER=""
CASE_BIN_FOLDER=""
RUN_STDOUT_FILE=""
RUN_STDERR_FILE=""
RUN_EXIT_CODE=0
CASE_COUNTER=0
RUN_STDIN_FILE=""

setup_test() {
    CASE_COUNTER=$((CASE_COUNTER + 1))
    CASE_FOLDER="${TMPDIR:-/tmp}/ssaSingleFileTest.$$.${CASE_COUNTER}"
    mkdir "$CASE_FOLDER" ||
        { printf 'cannot create case folder: %s\n' "$CASE_FOLDER" >&2
          exit 1; }
    REPLIES_FOLDER="$CASE_FOLDER/replies"
    CASE_TMPDIR="$CASE_FOLDER/sessions"
    CASE_BIN_FOLDER="$CASE_FOLDER/bin"
    mkdir "$REPLIES_FOLDER" "$CASE_TMPDIR" "$CASE_BIN_FOLDER"
    cp "$FAKE_CURL" "$CASE_BIN_FOLDER/curl" ||
        { printf 'cannot install fake curl\n' >&2; exit 1; }
    chmod +x "$CASE_BIN_FOLDER/curl"
    RUN_STDOUT_FILE="$CASE_FOLDER/stdout.txt"
    RUN_STDERR_FILE="$CASE_FOLDER/stderr.txt"
}

cleanup_test() {
    [ -n "$CASE_FOLDER" ] && rm -rf "$CASE_FOLDER"
    CASE_FOLDER=""
}

run_ssa() {
    STDIN_SOURCE=${RUN_STDIN_FILE:-/dev/null}
    env PATH="$CASE_BIN_FOLDER:$PATH" \
        TMPDIR="$CASE_TMPDIR" \
        SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
        SSA_MODEL="stubModel" \
        SSA_NO_ASK=1 \
        SSA_KEEP_TEMP=0 \
        OPENAI_URL="https://example.test/v1/chat/completions" \
        sh "$SSA_SCRIPT" --no-ask "$@" \
        <"$STDIN_SOURCE" \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
}

if [ -z "${TESTS_UTILS_LOADED:-}" ]; then
    TESTS_UTILS_LOADED=1
    TESTS_RUN=0
    TESTS_FAILED=0
fi
FAIL_REASON=""

fail() {
    FAIL_REASON="$1"
    return 1
}

expect_exit() {
    [ "$RUN_EXIT_CODE" = "$1" ] ||
        fail "expected exit $1, got $RUN_EXIT_CODE"
}

expect_stdout_has() {
    grep -qF -- "$1" "$RUN_STDOUT_FILE" ||
        fail "stdout missing: $1"
}

expect_stdout_lacks() {
    if grep -qF -- "$1" "$RUN_STDOUT_FILE"; then
        fail "stdout should not contain: $1"
        return 1
    fi
    return 0
}

expect_stderr_has() {
    grep -qF -- "$1" "$RUN_STDERR_FILE" ||
        fail "stderr missing: $1"
}

expect_transcript_has() {
    TRANSCRIPT=$(find "$CASE_TMPDIR" -name fullTranscript.txt \
        2>/dev/null | sed -n '1p')
    [ -n "$TRANSCRIPT" ] || { fail 'no kept transcript found'; return 1; }
    grep -qF -- "$1" "$TRANSCRIPT" ||
        { fail "transcript missing: $1"; return 1; }
}

finish_if_standalone() {
    [ -z "${SSA_TEST_RUNNER_ACTIVE:-}" ] || return 0
    printf '\n%s of %s tests passed\n' \
        "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
    [ "$TESTS_FAILED" = 0 ] || exit 1
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    FAIL_REASON=""
    setup_test
    if "$2"; then
        printf 'PASS  %s\n' "$1"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf 'FAIL  %s\n' "$1"
        [ -n "$FAIL_REASON" ] && printf '        %s\n' "$FAIL_REASON"
    fi
    cleanup_test
}
