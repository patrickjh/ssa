#!/bin/sh
# A non-numeric SSA_MAX_CONTEXT_BYTES is a usage error.

set -u
. "$TEST_UTILS_FILE"

SSA_MAX_CONTEXT_BYTES=nope \
    SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_NO_ASK=1 \
    run_ssa a task
expect_exit 1
expect_stderr_has 'invalid SSA_MAX_CONTEXT_BYTES'
