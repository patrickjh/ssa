#!/bin/sh
# SSA_CONTEXT=- is rejected; stdin is already the task.

set -u
. "$TEST_UTILS_FILE"

OPENAI_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_NO_ASK=1 \
    SSA_CONTEXT=- \
    run_ssa a task
expect_exit 1
expect_stderr_has 'SSA_CONTEXT cannot be -'
