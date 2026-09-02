#!/bin/sh
# No OPENAI_URL: usage error before the loop.

set -u
. "$TEST_UTILS_FILE"

unset OPENAI_URL
SSA_MODEL=fakeModel SSA_NO_ASK=1 run_ssa a task
expect_exit 1
expect_stderr_has 'OPENAI_URL not set'
