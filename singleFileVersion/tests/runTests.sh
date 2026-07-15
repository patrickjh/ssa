#!/bin/sh
# runTests.sh — offline sanity tests for singleFileVersion/ssa.
# See markdownForAgents/TESTS.md.

set -u

TESTS_FOLDER=$(CDPATH= cd -- "$(dirname "$0")" && pwd) ||
    { printf 'cannot resolve tests folder\n' >&2; exit 1; }
export TESTS_FOLDER
SSA_TEST_RUNNER_ACTIVE=1
export SSA_TEST_RUNNER_ACTIVE

. "$TESTS_FOLDER/testUtils.sh"

run_all_tests() {
    printf 'singleFileVersion ssa offline sanity tests\n\n'
    TEST_FILE_LIST=$(find "$TESTS_FOLDER" -type f -name '*.test.sh' | sort)
    [ -n "$TEST_FILE_LIST" ] ||
        { printf 'no *.test.sh files found under %s\n' "$TESTS_FOLDER" >&2
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

run_all_tests
