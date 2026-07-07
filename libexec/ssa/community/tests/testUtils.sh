# testUtils.sh — shared helpers for the ssa offline sanity tests.
#
# Sourced by runTests.sh and by each test case file. Not executable on
# its own. POSIX sh only, no non-POSIX utilities (e.g. no mktemp), so the
# suite runs anywhere the real harness runs.
#
# Provides:
#   - locations of the harness and stub runners
#   - canned reply writers (write_script_reply, write_done_reply)
#   - per-test scratch setup (new_case / end_case) using a POSIX temp dir
#   - run_ssa: run the real harness with the stub model runner
#   - assertions (expect_*) and a run_test driver
#
# Each test case defines one test_* function and a TEST_TITLE, then calls
# run_test with them. State is shared through the variables below.

# --- locations -------------------------------------------------------
TESTS_FOLDER=$(CDPATH= cd -- "$(dirname "$0")" && pwd) ||
    { printf 'cannot resolve tests folder\n' >&2; exit 1; }
REPO_FOLDER=$(CDPATH= cd -- "$TESTS_FOLDER/../../../.." && pwd) ||
    { printf 'cannot resolve repo folder\n' >&2; exit 1; }
SSA_SCRIPT="$REPO_FOLDER/libexec/ssa/ssa.sh"
STUB_MODEL_RUNNER="$TESTS_FOLDER/stubModelRunner.sh"
STUB_SCRIPT_RUNNER="$TESTS_FOLDER/stubScriptRunner.sh"

[ -f "$SSA_SCRIPT" ] || { printf 'not found: %s\n' "$SSA_SCRIPT" >&2
    exit 1; }
chmod +x "$STUB_MODEL_RUNNER" "$STUB_SCRIPT_RUNNER" 2>/dev/null

# --- canned reply fragments -----------------------------------------
DONE_SENTINEL='echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT'

# Write a well-formed reply that carries one ssa_script block.
# Usage: write_script_reply FILE SCRIPT_TEXT
write_script_reply() {
    printf 'THOUGHT: next step.\n\n```ssa_script\n%s\n```\n' "$2" >"$1"
}

# Write the exact done reply (single-line sentinel, no extra whitespace).
write_done_reply() {
    write_script_reply "$1" "$DONE_SENTINEL"
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
new_case() {
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

end_case() {
    [ -n "$CASE_FOLDER" ] && rm -rf "$CASE_FOLDER"
    CASE_FOLDER=""
}

# run_ssa [args...] — run the harness with the stub model runner and this
# case's private TMPDIR / replies. Captures stdout, stderr, exit code.
# Reads the piped task from RUN_STDIN_FILE when that variable is set.
RUN_STDIN_FILE=""
run_ssa() {
    if [ -n "$RUN_STDIN_FILE" ]; then
        env TMPDIR="$CASE_TMPDIR" \
            SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
            SSA_MODEL_RUNNER="$STUB_MODEL_RUNNER" \
            SSA_MODEL="stubModel" SSA_MODEL_CALLS=0 SSA_KEEP_SESSION=0 \
            sh "$SSA_SCRIPT" "$@" \
            <"$RUN_STDIN_FILE" \
            >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    else
        env TMPDIR="$CASE_TMPDIR" \
            SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
            SSA_MODEL_RUNNER="$STUB_MODEL_RUNNER" \
            SSA_MODEL="stubModel" SSA_MODEL_CALLS=0 SSA_KEEP_SESSION=0 \
            sh "$SSA_SCRIPT" "$@" \
            </dev/null \
            >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    fi
    RUN_EXIT_CODE=$?
}

# --- assertions ------------------------------------------------------
TESTS_RUN=0
TESTS_FAILED=0
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

# run_test TITLE FUNCTION — run one test in a fresh case folder, print
# PASS/FAIL, and track totals. Each test case file calls this once.
run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    FAIL_REASON=""
    new_case
    if "$2"; then
        printf 'PASS  %s\n' "$1"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf 'FAIL  %s\n' "$1"
        [ -n "$FAIL_REASON" ] && printf '        %s\n' "$FAIL_REASON"
    fi
    end_case
}
