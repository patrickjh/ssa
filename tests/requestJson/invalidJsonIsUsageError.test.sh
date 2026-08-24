#!/bin/sh
# --request-json with a non-object value is a usage error before the
# agent loop starts.

set -u
. "$TEST_UTILS_FILE"

run_ssa \
    --openai-url 'http://fake.test/chat/completions' \
    --model fakeModel \
    --request-json 'not-json' \
    a task
expect_exit 1
expect_stderr_has 'SSA_REQUEST_JSON must be a JSON object'
expect_stderr_has '--request-json'
