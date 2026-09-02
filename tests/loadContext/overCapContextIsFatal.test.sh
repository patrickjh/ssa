#!/bin/sh
# Context that makes system plus the first user turn over the cap dies
# at load, before curl.

set -u
. "$TEST_UTILS_FILE"

require_test_temp_folder
awk 'BEGIN { for (i = 0; i < 140000; i++) printf "x" }' \
    >"$TEST_TEMP_FOLDER/huge-context.txt" ||
    fail "cannot write huge context file"
OPENAI_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_NO_ASK=1 \
    SSA_CONTEXT="$TEST_TEMP_FOLDER/huge-context.txt" \
    run_ssa a task
expect_exit 1
expect_stderr_has 'system prompt and first user turn exceed the messages'
