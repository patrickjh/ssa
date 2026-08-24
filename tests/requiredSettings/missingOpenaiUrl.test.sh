#!/bin/sh
# No --openai-url and no OPENAI_URL: usage error before the loop.

set -u
. "$TEST_UTILS_FILE"

unset OPENAI_URL
run_ssa --model fakeModel --no-ask a task
expect_exit 1
expect_stderr_has 'OPENAI_URL not set'
expect_stderr_has '--openai-url'
