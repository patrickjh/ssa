#!/bin/sh
# runTests.sh — only supported way to run story tests.
# Starts each *.test.sh in a background process with its own temp
# folder and harness env. Prints FAIL lines only; exit 0 if all pass.
# Usage:
#   sh tests/runTests.sh

set -u

# Private to the runner
CLEANED=0
FAILED=0
JOBS_FOLDER=""
TEST_COUNTER=0
TEST_UTILS_FILE=""
TESTS_FOLDER=""

main() {
    setup_test_runner
    check_any_tests_found
    trap handle_interrupt INT
    trap handle_terminate TERM
    trap 'EXIT_STATUS=$?; cleanup_all_tests; exit $EXIT_STATUS' EXIT
    start_all_tests
    wait_all_tests
    [ "$FAILED" = 0 ]
}

setup_test_runner() {
    TESTS_FOLDER=$(CDPATH= cd -- "$(dirname "$0")" && pwd) ||
        { printf 'cannot resolve tests folder\n' >&2; exit 1; }
    TEST_UTILS_FILE="$TESTS_FOLDER/testUtils.sh"
    [ -f "$TEST_UTILS_FILE" ] ||
        { printf 'not found: %s\n' "$TEST_UTILS_FILE" >&2; exit 1; }
}

check_any_tests_found() {
    for TEST_SCRIPT in "$TESTS_FOLDER"/*/*.test.sh; do
        [ -f "$TEST_SCRIPT" ] && return 0
    done
    printf 'no *.test.sh files found under %s\n' "$TESTS_FOLDER" >&2
    exit 1
}

handle_interrupt() {
    exit 130
}

handle_terminate() {
    exit 143
}

start_all_tests() {
    setup_jobs_folder
    for TEST_SCRIPT in "$TESTS_FOLDER"/*/*.test.sh; do
        [ -f "$TEST_SCRIPT" ] || continue
        start_one_test
    done
}

setup_jobs_folder() {
    JOBS_FOLDER="${TMPDIR:-/tmp}/ssaTestRunner.$$"
    mkdir "$JOBS_FOLDER" ||
        { printf 'cannot create jobs folder: %s\n' "$JOBS_FOLDER" >&2
          exit 1; }
}

start_one_test() {
    TEST_COUNTER=$((TEST_COUNTER + 1))
    CASE_TEMP="${TMPDIR:-/tmp}/ssaTest.$$.${TEST_COUNTER}"
    mkdir "$CASE_TEMP" ||
        { printf 'cannot create temp folder: %s\n' "$CASE_TEMP" >&2
          exit 1; }
    TEST_TEMP_FOLDER="$CASE_TEMP" \
        TEST_UTILS_FILE="$TEST_UTILS_FILE" \
        sh "$TEST_SCRIPT" &
    TEST_PID=$!
    record_test_job
}

record_test_job() {
    printf '%s\n' "$TEST_PID" >>"$JOBS_FOLDER/pids" ||
        { printf 'cannot record test pid\n' >&2; exit 1; }
    printf '%s\n' "${TEST_SCRIPT#"$TESTS_FOLDER"/}" \
        >"$JOBS_FOLDER/$TEST_PID.path" ||
        { printf 'cannot record test path\n' >&2; exit 1; }
    printf '%s\n' "$CASE_TEMP" >"$JOBS_FOLDER/$TEST_PID.temp" ||
        { printf 'cannot record test temp\n' >&2; exit 1; }
}

wait_all_tests() {
    [ -f "$JOBS_FOLDER/pids" ] || return 0
    while IFS= read -r TEST_PID; do
        [ -n "$TEST_PID" ] || continue
        wait "$TEST_PID"
        TEST_STATUS=$?
        if [ "$TEST_STATUS" != 0 ]; then
            printf 'FAIL  %s\n' "$(cat "$JOBS_FOLDER/$TEST_PID.path")"
            FAILED=1
        fi
    done <"$JOBS_FOLDER/pids"
}

cleanup_all_tests() {
    [ "$CLEANED" = 1 ] && return 0
    CLEANED=1
    kill_test_jobs
    wait_test_jobs
    remove_test_temps
    if [ -n "$JOBS_FOLDER" ]; then
        rm -rf "$JOBS_FOLDER"
    fi
}

kill_test_jobs() {
    [ -n "$JOBS_FOLDER" ] || return 0
    [ -f "$JOBS_FOLDER/pids" ] || return 0
    while IFS= read -r TEST_PID; do
        [ -n "$TEST_PID" ] || continue
        kill "$TEST_PID" 2>/dev/null || :
    done <"$JOBS_FOLDER/pids"
}

wait_test_jobs() {
    [ -n "$JOBS_FOLDER" ] || return 0
    [ -f "$JOBS_FOLDER/pids" ] || return 0
    while IFS= read -r TEST_PID; do
        [ -n "$TEST_PID" ] || continue
        wait "$TEST_PID" 2>/dev/null || :
    done <"$JOBS_FOLDER/pids"
}

remove_test_temps() {
    [ -n "$JOBS_FOLDER" ] || return 0
    [ -f "$JOBS_FOLDER/pids" ] || return 0
    while IFS= read -r TEST_PID; do
        [ -n "$TEST_PID" ] || continue
        [ -f "$JOBS_FOLDER/$TEST_PID.temp" ] || continue
        rm -rf "$(cat "$JOBS_FOLDER/$TEST_PID.temp")"
    done <"$JOBS_FOLDER/pids"
}

main
