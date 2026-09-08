#!/bin/sh
# SSA_NO_EDITS=2 is a usage error before the loop.

set -u
. "$TEST_UTILS_FILE"

SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_NO_ASK=1 \
    SSA_NO_EDITS=2 \
    run_ssa a task
expect_exit 1
expect_stderr_has 'SSA_NO_EDITS must be 0 or 1'
expect_stderr_has 'see ssa -h for help'
