#!/bin/sh
# runTests.sh — run user-story tests for ssa.
# Usage:
#   sh tests/runTests.sh
#   sh tests/runTests.sh showHelp

set -u

STORIES_FOLDER=$(CDPATH= cd -- "$(dirname "$0")" && pwd) ||
    { printf 'cannot resolve tests folder\n' >&2; exit 1; }
REPO_FOLDER=$(CDPATH= cd -- "$STORIES_FOLDER/.." && pwd) ||
    { printf 'cannot resolve repo folder\n' >&2; exit 1; }
# STORIES_FOLDER is tests/; each camelCase subfolder is one story.
SSA_SCRIPT="$REPO_FOLDER/ssa"

[ -f "$SSA_SCRIPT" ] ||
    { printf 'not found: %s\n' "$SSA_SCRIPT" >&2; exit 1; }

TESTS_RUN=0
TESTS_FAILED=0
FAIL_REASON=""
CASE_FOLDER=""
RUN_STDOUT_FILE=""
RUN_STDERR_FILE=""
RUN_EXIT_CODE=0
CASE_COUNTER=0

setup_test() {
    CASE_COUNTER=$((CASE_COUNTER + 1))
    CASE_FOLDER="${TMPDIR:-/tmp}/ssaStoryTest.$$.${CASE_COUNTER}"
    mkdir "$CASE_FOLDER" ||
        { printf 'cannot create case folder: %s\n' "$CASE_FOLDER" >&2
          exit 1; }
    RUN_STDOUT_FILE="$CASE_FOLDER/stdout.txt"
    RUN_STDERR_FILE="$CASE_FOLDER/stderr.txt"
}

cleanup_test() {
    [ -n "$CASE_FOLDER" ] && rm -rf "$CASE_FOLDER"
    CASE_FOLDER=""
}

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

expect_stderr_empty() {
    [ ! -s "$RUN_STDERR_FILE" ] ||
        fail "stderr should be empty"
}

run_ssa() {
    sh "$SSA_SCRIPT" "$@" \
        </dev/null \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
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

run_all_tests() {
    FILTER=${1-}
    printf 'ssa user story tests\n\n'
    if [ -n "$FILTER" ]; then
        SEARCH_ROOT="$STORIES_FOLDER/$FILTER"
        [ -d "$SEARCH_ROOT" ] ||
            { printf 'story folder not found: %s\n' "$FILTER" >&2
              exit 1; }
    else
        SEARCH_ROOT=$STORIES_FOLDER
    fi
    TEST_FILE_LIST=$(find "$SEARCH_ROOT" -type f -name '*.test.sh' | sort)
    [ -n "$TEST_FILE_LIST" ] ||
        { printf 'no *.test.sh files found under %s\n' "$SEARCH_ROOT" >&2
          exit 1; }
    OLD_IFS=$IFS
    IFS='
'
    for CASE_FILE in $TEST_FILE_LIST; do
        IFS=$OLD_IFS
        . "$CASE_FILE"
        IFS='
'
    done
    IFS=$OLD_IFS

    printf '\n%s of %s tests passed\n' \
        "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
    [ "$TESTS_FAILED" = 0 ] || exit 1
}

run_all_tests "$@"
