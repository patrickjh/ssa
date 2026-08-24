#!/bin/sh
# No -m / --model and no SSA_MODEL: usage error before the loop.

set -u
. "$TEST_UTILS_FILE"

unset SSA_MODEL
run_ssa --openai-url 'http://fake.test/chat/completions' --no-ask a task
expect_exit 1
expect_stderr_has 'model not set'
expect_stderr_has '-m / --model'
