#!/bin/sh
# A context file with a NUL dies at load; jq cannot hold it.

set -u
. "$TEST_UTILS_FILE"

require_test_temp_folder
printf '\0' >"$TEST_TEMP_FOLDER/nul-context.txt" ||
    fail "cannot write nul context file"
SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_NO_ASK=1 \
    SSA_CONTEXT="$TEST_TEMP_FOLDER/nul-context.txt" \
    run_ssa a task
expect_exit 1
expect_stderr_has 'context file is not valid UTF-8'
