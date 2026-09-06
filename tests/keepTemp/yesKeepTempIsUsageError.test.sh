#!/bin/sh
# SSA_KEEP_TEMP=yes is a usage error before the loop.

set -u
. "$TEST_UTILS_FILE"

SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_NO_ASK=1 \
    SSA_KEEP_TEMP=yes \
    run_ssa a task
expect_exit 1
expect_stderr_has 'SSA_KEEP_TEMP must be 0 or 1'
