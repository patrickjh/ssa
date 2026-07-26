#!/bin/sh
# runTests.sh — only supported way to run story tests.
# Sets up a per-test temp folder (with EXIT trap cleanup), exports harness
# env for the child, then runs each *.test.sh as its own process.
# Prints FAIL lines only; exit 0 if all pass.
# Usage:
#   sh tests/runTests.sh

set -u

# Exported for each *.test.sh child
export TEST_TEMP_FOLDER=""
export TEST_UTILS_FILE=""

# Private to the runner
FAILED=0
TEST_COUNTER=0
TESTS_FOLDER=""

main() {
    setup_test_runner
    check_any_tests_found
    run_all_tests
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

run_all_tests() {
    for TEST_SCRIPT in "$TESTS_FOLDER"/*/*.test.sh; do
        [ -f "$TEST_SCRIPT" ] || continue
        setup_test
        if ! sh "$TEST_SCRIPT"; then
            printf 'FAIL  %s\n' "${TEST_SCRIPT#"$TESTS_FOLDER"/}"
            FAILED=1
        fi
        cleanup_test
    done
    [ "$FAILED" = 0 ]
}

setup_test() {
    TEST_COUNTER=$((TEST_COUNTER + 1))
    TEST_TEMP_FOLDER="${TMPDIR:-/tmp}/ssaTest.$$.${TEST_COUNTER}"
    mkdir "$TEST_TEMP_FOLDER" ||
        { printf 'cannot create temp folder: %s\n' "$TEST_TEMP_FOLDER" >&2
          exit 1; }
    trap cleanup_test EXIT
}

cleanup_test() {
    if [ -n "${TEST_TEMP_FOLDER:-}" ]; then
        rm -rf "$TEST_TEMP_FOLDER"
    fi
    TEST_TEMP_FOLDER=""
    trap - EXIT
}

main
