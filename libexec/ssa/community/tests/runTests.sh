#!/bin/sh
# runTests.sh — offline sanity tests for the ssa harness (entry point).
#
# Exercises the real agent loop in libexec/ssa/ssa.sh with a stub model
# runner (stubModelRunner.sh) that replays canned replies, so the suite
# runs offline: no network, no llama.cpp. Where useful a stub script
# runner (stubScriptRunner.sh) proves the script-runner path.
#
# Layout: shared helpers live in testUtils.sh; each test case is its own
# test*.sh file that defines one test_* function and calls run_test. This
# file sources the shared helpers, then sources each test case file in
# turn, so adding a test means dropping a new test*.sh here.
#
# Run:   sh libexec/ssa/community/tests/runTests.sh
# Prints PASS / FAIL per test and exits non-zero if any test fails.

set -u

THIS_FOLDER=$(CDPATH= cd -- "$(dirname "$0")" && pwd) ||
    { printf 'cannot resolve tests folder\n' >&2; exit 1; }

. "$THIS_FOLDER/testUtils.sh"

# Test case files, in the order they should run. Each sourced file
# defines its test_* function and calls run_test once.
TEST_CASE_FILES='
testHappyPath.sh
testDoneEdgeCases.sh
testFormatErrorsRetry.sh
testMaxModelCalls.sh
testTaskFromArgv.sh
testTaskFromStdin.sh
testMissingModelRunner.sh
testStreamAndTranscript.sh
'

main() {
    printf 'ssa offline sanity tests\n\n'
    for CASE_FILE in $TEST_CASE_FILES; do
        [ -f "$THIS_FOLDER/$CASE_FILE" ] ||
            { printf 'missing test case file: %s\n' "$CASE_FILE" >&2
              exit 1; }
        . "$THIS_FOLDER/$CASE_FILE"
    done

    printf '\n%s of %s tests passed\n' \
        "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
    [ "$TESTS_FAILED" = 0 ] || exit 1
}

main "$@"
