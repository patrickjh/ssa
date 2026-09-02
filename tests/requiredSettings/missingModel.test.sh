#!/bin/sh
# No SSA_MODEL: usage error before the loop.

set -u
. "$TEST_UTILS_FILE"

unset SSA_MODEL
SSA_URL='http://fake.test/chat/completions' SSA_NO_ASK=1 run_ssa a task
expect_exit 1
expect_stderr_has 'model not set'
expect_stderr_has 'SSA_MODEL'
