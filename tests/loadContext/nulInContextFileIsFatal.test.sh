#!/bin/sh
# Stdin with a NUL dies at load; jq cannot hold it.

set -u
. "$TEST_UTILS_FILE"

require_test_temp_folder
printf '\0' >"$TEST_TEMP_FOLDER/nul-context.txt" ||
    fail "cannot write nul context file"
SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_NO_ASK=1 \
    run_ssa_from_stdin a task <"$TEST_TEMP_FOLDER/nul-context.txt"
expect_exit 1
expect_stderr_has 'context file is not valid UTF-8'
