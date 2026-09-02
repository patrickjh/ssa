#!/bin/sh
# No SSA_URL: usage error before the loop.

set -u
. "$TEST_UTILS_FILE"

unset SSA_URL
SSA_MODEL=fakeModel SSA_NO_ASK=1 run_ssa a task
expect_exit 1
expect_stderr_has 'SSA_URL not set'
