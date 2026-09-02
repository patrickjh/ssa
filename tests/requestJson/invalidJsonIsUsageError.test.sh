#!/bin/sh
# SSA_REQUEST_JSON with a non-object value is a usage error before the
# agent loop starts.

set -u
. "$TEST_UTILS_FILE"

SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel \
    SSA_REQUEST_JSON='not-json' \
    run_ssa a task
expect_exit 1
expect_stderr_has 'SSA_REQUEST_JSON must be a JSON object'
