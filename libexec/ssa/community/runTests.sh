#!/bin/sh
# runTests.sh — offline sanity tests for the ssa harness (entry point).
#
# Exercises the real agent loop in libexec/ssa/ssa.sh with a stub model
# runner (stubModelRunner.sh) that replays canned replies, so the suite
# runs offline: no network, no llama.cpp. Where useful a stub script
# runner (stubScriptRunner.sh) proves the script-runner path.
#
# Layout: this file and the shared helpers (testUtils.sh) plus the stub
# runners live in the community folder; the tests/ subfolder holds only
# test case files. Each test*.sh defines one test_* function, sources
# testUtils.sh itself, and calls run_test. This runner recursively scans
# tests/ for test*.sh files and sources each, so adding a test just means
# dropping a new test*.sh into tests/ (or a subfolder of it).
#
# Run:   sh libexec/ssa/community/runTests.sh
# Prints PASS / FAIL per test and exits non-zero if any test fails.

set -u

# Absolute path to the community folder (this file's folder). Exported so
# testUtils.sh and each sourced test case resolve paths from one place.
COMMUNITY_FOLDER=$(CDPATH= cd -- "$(dirname "$0")" && pwd) ||
    { printf 'cannot resolve community folder\n' >&2; exit 1; }
export COMMUNITY_FOLDER
# Tell sourced test files the runner owns the summary/exit, so their
# finish_if_standalone call is a no-op.
SSA_TEST_RUNNER_ACTIVE=1
export SSA_TEST_RUNNER_ACTIVE
TESTS_FOLDER="$COMMUNITY_FOLDER/tests"

[ -d "$TESTS_FOLDER" ] ||
    { printf 'tests folder not found: %s\n' "$TESTS_FOLDER" >&2; exit 1; }

. "$COMMUNITY_FOLDER/testUtils.sh"

# Build a newline list of test files once, then source them in the
# current shell so TESTS_RUN / TESTS_FAILED accumulate here (a piped
# while runs in a subshell and would lose the totals). find + sort are
# POSIX; the scan is recursive so future subfolders under tests/ are
# picked up too.
run_all_tests() {
    printf 'ssa offline sanity tests\n\n'
    TEST_FILE_LIST=$(find "$TESTS_FOLDER" -type f -name 'test*.sh' | sort)
    [ -n "$TEST_FILE_LIST" ] ||
        { printf 'no test files found under %s\n' "$TESTS_FOLDER" >&2
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
