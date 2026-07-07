#!/bin/sh
# runTests.sh — offline sanity tests for the ssa harness.
#
# These tests exercise the real agent loop in libexec/ssa/ssa.sh with a
# stub model runner (stubModelRunner.sh) that replays canned replies, so
# the suite runs offline: no network, no llama.cpp. Where useful a stub
# script runner (stubScriptRunner.sh) proves the script-runner path.
#
# Run:   sh libexec/ssa/community/tests/runTests.sh
# Prints PASS / FAIL per test and exits non-zero if any test fails.
#
# The tests assert the contract the code on main actually implements. In
# one place (done detection) that differs from the DESIGN.md wording; see
# the note in test_done_edge_cases below.

set -u

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

new_case() {
    CASE_FOLDER=$(mktemp -d "${TMPDIR:-/tmp}/ssaTestCase.XXXXXX") ||
        { printf 'mktemp failed\n' >&2; exit 1; }
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

# run_test NAME FUNCTION — run one test, print PASS/FAIL, track totals.
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

# --- tests -----------------------------------------------------------

# (1) Happy path: one scripted turn, then the done sentinel exits 0 with
# the done status on stderr.
test_happy_path() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" \
        'echo happy-path-output'
    write_done_reply "$REPLIES_FOLDER/reply2.txt"
    run_ssa complete the happy path
    expect_exit 0 || return 1
    expect_stdout_has 'happy-path-output' || return 1
    expect_stderr_has 'done: task complete after 2 model calls' || return 1
}

# (2) Done detection edge cases. The code on main (agent_is_done in
# ssa.sh) treats a script as done only when it matches the sentinel
# string EXACTLY. DESIGN.md describes trimming the first non-empty line,
# but the code does a full-string compare with no trimming, so a sentinel
# with leading/trailing whitespace or surrounding blank lines is NOT
# treated as done — it runs as an ordinary script. These tests pin that
# actual contract.
test_done_edge_cases() {
    # A sentinel wrapped in blank lines and padded with spaces must NOT
    # trigger done: it runs, printing the sentinel word to stdout, and
    # the loop continues to the next (real) done reply.
    printf 'THOUGHT: padded.\n\n```ssa_script\n\n  %s  \n\n```\n' \
        "$DONE_SENTINEL" >"$REPLIES_FOLDER/reply1.txt"
    write_done_reply "$REPLIES_FOLDER/reply2.txt"
    run_ssa done edge cases
    expect_exit 0 || return 1
    # The padded sentinel ran as a script, so its echo reached stdout.
    expect_stdout_has 'COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT' || return 1
    # Two model calls means turn 1 was not treated as done.
    expect_stderr_has 'done: task complete after 2 model calls' || return 1
}

# (3) Parse / format errors: a reply with no ssa_script fence, one with
# two fences, and one with an empty script each append a format error and
# retry. A fourth, valid done reply then ends the run.
test_format_errors_retry() {
    # no fence
    printf 'THOUGHT: no fence at all here.\n' \
        >"$REPLIES_FOLDER/reply1.txt"
    # two fences
    printf 'THOUGHT: two.\n\n```ssa_script\necho a\n```\n\n%s\n' \
        '```ssa_script
echo b
```' >"$REPLIES_FOLDER/reply2.txt"
    # empty script
    printf 'THOUGHT: empty.\n\n```ssa_script\n```\n' \
        >"$REPLIES_FOLDER/reply3.txt"
    write_done_reply "$REPLIES_FOLDER/reply4.txt"
    run_ssa format errors retry
    expect_exit 0 || return 1
    expect_stderr_has 'done: task complete after 4 model calls' || return 1
    # Three format errors were fed back into the transcript. Confirm via
    # a kept session so we can read the transcript.
    run_keep_and_count_format_errors 3 || return 1
}

# Re-run the same three-error-then-done sequence with --keep-session and
# assert the transcript contains exactly N "Format error" feedbacks.
run_keep_and_count_format_errors() {
    printf 'THOUGHT: no fence at all here.\n' \
        >"$REPLIES_FOLDER/reply1.txt"
    printf 'THOUGHT: two.\n\n```ssa_script\necho a\n```\n\n%s\n' \
        '```ssa_script
echo b
```' >"$REPLIES_FOLDER/reply2.txt"
    printf 'THOUGHT: empty.\n\n```ssa_script\n```\n' \
        >"$REPLIES_FOLDER/reply3.txt"
    write_done_reply "$REPLIES_FOLDER/reply4.txt"
    run_ssa --keep-session format errors retry
    TRANSCRIPT=$(find "$CASE_TMPDIR" -name sessionTranscript.txt \
        2>/dev/null | head -n 1)
    [ -n "$TRANSCRIPT" ] || { fail 'no kept transcript found'; return 1; }
    COUNT=$(grep -c 'Format error' "$TRANSCRIPT")
    [ "$COUNT" = "$1" ] ||
        { fail "expected $1 format errors, got $COUNT"; return 1; }
}

# (4) --max-model-calls N stops with exit 1 and the hit-max message.
test_max_model_calls() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" 'echo step-one'
    write_script_reply "$REPLIES_FOLDER/reply2.txt" 'echo step-two'
    run_ssa --max-model-calls 1 keep going forever
    expect_exit 1 || return 1
    expect_stderr_has \
        'hit max: stopped after SSA_MAX_MODEL_CALLS (1)' || return 1
}

# (5a) Task from argv. Keep the session and grep the transcript for the
# argv words, so the test verifies the task actually routed into the
# prompt (not just that any run reached the done status).
test_task_from_argv() {
    write_done_reply "$REPLIES_FOLDER/reply1.txt"
    run_ssa --keep-session task-words-came-from-argv
    expect_exit 0 || return 1
    expect_stderr_has 'done: task complete' || return 1
    expect_transcript_has 'task-words-came-from-argv' || return 1
}

# (5b) Task piped on stdin. Same transcript check as argv, proving the
# stdin task text reached the prompt.
test_task_from_stdin() {
    write_done_reply "$REPLIES_FOLDER/reply1.txt"
    printf 'task-words-came-from-stdin\n' >"$CASE_FOLDER/task.txt"
    RUN_STDIN_FILE="$CASE_FOLDER/task.txt"
    run_ssa --keep-session
    RUN_STDIN_FILE=""
    expect_exit 0 || return 1
    expect_stderr_has 'done: task complete' || return 1
    expect_transcript_has 'task-words-came-from-stdin' || return 1
}

# (6) Missing model runner fails at startup via util_die with exit 1.
test_missing_model_runner() {
    write_done_reply "$REPLIES_FOLDER/reply1.txt"
    env TMPDIR="$CASE_TMPDIR" \
        SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
        SSA_MODEL="stubModel" SSA_MODEL_CALLS=0 SSA_KEEP_SESSION=0 \
        sh "$SSA_SCRIPT" no runner set here </dev/null \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
    expect_exit 1 || return 1
    expect_stderr_has 'model runner not set' || return 1
}

# (7) Script output is streamed to stdout and appears in the transcript
# when run with --keep-session. Also proves the configured script runner
# (SSA_SCRIPT_RUNNER) is on the path by checking for its marker.
test_stream_and_transcript() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" \
        'echo streamed-marker-line'
    write_done_reply "$REPLIES_FOLDER/reply2.txt"
    env TMPDIR="$CASE_TMPDIR" \
        SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
        SSA_MODEL_RUNNER="$STUB_MODEL_RUNNER" \
        SSA_SCRIPT_RUNNER="$STUB_SCRIPT_RUNNER" \
        SSA_MODEL="stubModel" SSA_MODEL_CALLS=0 \
        sh "$SSA_SCRIPT" --keep-session stream to stdout </dev/null \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
    expect_exit 0 || return 1
    # Streamed live to stdout.
    expect_stdout_has 'streamed-marker-line' || return 1
    # Script runner path was used.
    expect_stdout_has 'STUB_SCRIPT_RUNNER_RAN' || return 1
    # And recorded in the kept transcript.
    TRANSCRIPT=$(find "$CASE_TMPDIR" -name sessionTranscript.txt \
        2>/dev/null | head -n 1)
    [ -n "$TRANSCRIPT" ] ||
        { fail 'no kept transcript found'; return 1; }
    grep -qF 'streamed-marker-line' "$TRANSCRIPT" ||
        { fail 'transcript missing streamed output'; return 1; }
}

# --- main ------------------------------------------------------------
main() {
    printf 'ssa offline sanity tests\n\n'
    run_test 'happy path: scripted turn then done sentinel' \
        test_happy_path
    run_test 'done detection edge cases (exact-match contract)' \
        test_done_edge_cases
    run_test 'parse/format errors append feedback and retry' \
        test_format_errors_retry
    run_test '--max-model-calls stops with hit-max message' \
        test_max_model_calls
    run_test 'task from argv' test_task_from_argv
    run_test 'task from piped stdin' test_task_from_stdin
    run_test 'missing model runner fails at startup' \
        test_missing_model_runner
    run_test 'script output streamed and in transcript' \
        test_stream_and_transcript

    printf '\n%s of %s tests passed\n' \
        "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
    [ "$TESTS_FAILED" = 0 ] || exit 1
}

main "$@"
