#!/bin/sh
# testUtils.sh — helpers for story tests (sourced by *.test.sh).
# Defines functions only; does nothing when sourced.
# Expects runTests.sh to have exported TEST_TEMP_FOLDER and
# TEST_UTILS_FILE.

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_test_temp_folder() {
    [ -n "${TEST_TEMP_FOLDER:-}" ] ||
        fail "TEST_TEMP_FOLDER not set; run via tests/runTests.sh"
}

get_ssa_path() {
    [ -n "${TEST_UTILS_FILE:-}" ] ||
        fail "TEST_UTILS_FILE not set; run via tests/runTests.sh"
    SSA_PATH=$(CDPATH= cd -- "$(dirname "$TEST_UTILS_FILE")/.." && pwd)/ssa ||
        fail "cannot resolve ssa"
    [ -f "$SSA_PATH" ] || fail "not found: $SSA_PATH"
    printf '%s\n' "$SSA_PATH"
}

run_ssa() {
    require_test_temp_folder
    sh "$(get_ssa_path)" "$@" \
        </dev/null \
        >"$TEST_TEMP_FOLDER/stdout.txt" 2>"$TEST_TEMP_FOLDER/stderr.txt"
    SSA_EXIT_CODE=$?
}

expect_exit() {
    [ "${SSA_EXIT_CODE-}" = "$1" ] ||
        fail "expected exit $1, got ${SSA_EXIT_CODE-}"
}

expect_stdout_has() {
    require_test_temp_folder
    grep -qF -- "$1" "$TEST_TEMP_FOLDER/stdout.txt" ||
        fail "stdout missing: $1"
}

expect_stderr_empty() {
    require_test_temp_folder
    [ ! -s "$TEST_TEMP_FOLDER/stderr.txt" ] ||
        fail "stderr should be empty"
}
