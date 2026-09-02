#!/bin/sh
# SSA_CONTEXT pointing at a missing file dies before the loop.

set -u
. "$TEST_UTILS_FILE"

require_test_temp_folder
OPENAI_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_NO_ASK=1 \
    SSA_CONTEXT="$TEST_TEMP_FOLDER/missing-context.txt" \
    run_ssa a task
expect_exit 1
expect_stderr_has 'context file not a readable regular file'
expect_stderr_has 'set SSA_CONTEXT'
