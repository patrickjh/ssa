# testUtils.sh — shared helpers for the ssa offline sanity tests.
#
# Sourced by runTests.sh and directly by each test case file. Not
# executable on its own. POSIX sh only, no non-POSIX utilities (e.g. no
# mktemp), so the suite runs anywhere the real harness runs.
#
# The sourcing file must set COMMUNITY_FOLDER to the absolute path of the
# community folder (the folder holding this file) before sourcing.
#
# Provides:
#   - locations of the harness and stub runners
#   - a canned reply writer (write_script_reply)
#   - per-test scratch setup (setup_test / cleanup_test) via a POSIX dir
#   - run_ssa: run the real harness with the stub model runner
#   - assertions (expect_*) and a run_test driver
#
# Each test case defines one test_* function and a TEST_TITLE, then calls
# run_test with them. State is shared through the variables below.

# --- locations -------------------------------------------------------
# COMMUNITY_FOLDER is set by whoever sources this file (runTests.sh, or a
# test case run standalone). Everything else is derived from it, so this
# file works whether it is sourced by the runner or by a single test.
[ -n "${COMMUNITY_FOLDER:-}" ] ||
    { printf 'testUtils.sh: COMMUNITY_FOLDER not set\n' >&2; exit 1; }
REPO_FOLDER=$(CDPATH= cd -- "$COMMUNITY_FOLDER/../../.." && pwd) ||
    { printf 'cannot resolve repo folder\n' >&2; exit 1; }
SSA_SCRIPT="$REPO_FOLDER/libexec/ssa/ssa.sh"
STUB_MODEL_RUNNER="$COMMUNITY_FOLDER/stubModelRunner.sh"
STUB_SCRIPT_RUNNER="$COMMUNITY_FOLDER/stubScriptRunner.sh"

[ -f "$SSA_SCRIPT" ] || { printf 'not found: %s\n' "$SSA_SCRIPT" >&2
    exit 1; }
chmod +x "$STUB_MODEL_RUNNER" "$STUB_SCRIPT_RUNNER" 2>/dev/null

# --- canned reply fragments -----------------------------------------
# The exact string the harness treats as done (agent_is_done in ssa.sh
# does a full-string compare against it). Tests use this verbatim so the
# done payload is visible at each call site.
DONE_SENTINEL='echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT'

# Write a well-formed reply that carries one ssa_script block.
# Usage: write_script_reply FILE SCRIPT_TEXT
write_script_reply() {
    printf 'THOUGHT: next step.\n\n```ssa_script\n%s\n```\n' "$2" >"$1"
}

# --- per-test scratch and run helper --------------------------------
# Each test gets its own work folder holding the canned replies and a
# private TMPDIR, so the ssa session folder (named to 1-second
# resolution) never collides between tests.
CASE_FOLDER=""
CASE_TMPDIR=""
REPLIES_FOLDER=""
RUN_STDOUT_FILE=""
RUN_STDERR_FILE=""
RUN_EXIT_CODE=0
CASE_COUNTER=0

# Make a private work folder without mktemp (not POSIX). The name uses
# this suite's pid plus a per-run counter, so folders are unique within
# the run; mkdir fails (set -C style) if a name somehow already exists.
setup_test() {
    CASE_COUNTER=$((CASE_COUNTER + 1))
    CASE_FOLDER="${TMPDIR:-/tmp}/ssaTestCase.$$.${CASE_COUNTER}"
    mkdir "$CASE_FOLDER" ||
        { printf 'cannot create case folder: %s\n' "$CASE_FOLDER" >&2
          exit 1; }
    REPLIES_FOLDER="$CASE_FOLDER/replies"
    CASE_TMPDIR="$CASE_FOLDER/sessions"
    mkdir "$REPLIES_FOLDER" "$CASE_TMPDIR"
    RUN_STDOUT_FILE="$CASE_FOLDER/stdout.txt"
    RUN_STDERR_FILE="$CASE_FOLDER/stderr.txt"
}

cleanup_test() {
    [ -n "$CASE_FOLDER" ] && rm -rf "$CASE_FOLDER"
    CASE_FOLDER=""
}

# run_ssa [args...] — run the harness with the stub model runner and this
# case's private TMPDIR / replies. Captures stdout, stderr, exit code.
# The only thing that varies is the task source: a test sets
# RUN_STDIN_FILE to pipe the task on stdin; otherwise stdin is /dev/null
# and the task comes from argv.
RUN_STDIN_FILE=""
run_ssa() {
    STDIN_SOURCE=${RUN_STDIN_FILE:-/dev/null}
    env TMPDIR="$CASE_TMPDIR" \
        SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
        SSA_MODEL_RUNNER="$STUB_MODEL_RUNNER" \
        SSA_MODEL="stubModel" SSA_MODEL_CALLS=0 SSA_KEEP_SESSION=0 \
        sh "$SSA_SCRIPT" "$@" \
        <"$STDIN_SOURCE" \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
}

# --- assertions ------------------------------------------------------
# Totals persist across re-sourcing: each test file sources this helper,
# and the runner sources several test files into one shell, so guard the
# counters against being reset back to 0 on a second source.
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

# Assert the kept session transcript contains a string. Requires the run
# to have used --keep-session so the session folder survives.
expect_transcript_has() {
    TRANSCRIPT=$(find "$CASE_TMPDIR" -name sessionTranscript.txt \
        2>/dev/null | head -n 1)
    [ -n "$TRANSCRIPT" ] || { fail 'no kept transcript found'; return 1; }
    grep -qF -- "$1" "$TRANSCRIPT" ||
        { fail "transcript missing: $1"; return 1; }
}

# finish_if_standalone — when a test file is run on its own (not sourced
# by runTests.sh), print the summary line and exit non-zero if it failed.
# When the runner is active (SSA_TEST_RUNNER_ACTIVE set), this is a no-op
# so the runner owns the summary and exit. Each test file calls this last.
finish_if_standalone() {
    [ -z "${SSA_TEST_RUNNER_ACTIVE:-}" ] || return 0
    printf '\n%s of %s tests passed\n' \
        "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
    [ "$TESTS_FAILED" = 0 ] || exit 1
}

# run_test TITLE FUNCTION — run one test in a fresh case folder, print
# PASS/FAIL, and track totals. Each test case file calls this once.
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
